[#ftl]

[#assign AWS_EC2_AUTO_SCALE_GROUP_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[#assign AWS_EC2_EBS_VOLUME_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_EC2_AUTO_SCALE_GROUP_RESOURCE_TYPE
    mappings=AWS_EC2_AUTO_SCALE_GROUP_OUTPUT_MAPPINGS
/]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_EC2_EBS_RESOURCE_TYPE
    mappings=AWS_EC2_EBS_VOLUME_OUTPUT_MAPPINGS
/]

[#function getCFNInitFromComputeTasks computeTaskConfig ]

    [#local configSetName = ""]

    [#local cfnInitTasks = {}]
    [#local configSetTaskList = []]
    [#list computeTaskConfig as id, task ]
        [#if ((task[AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE])!{})?has_content ]
            [#local cfnInitTask = task[AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE]]

            [#local configSetName = cfnInitTask.ComputeResourceId ]

            [#if ((cfnInitTask.Content)!{})?has_content ]

                [#local configSetId = "${cfnInitTask.Priorty}_${id}" ]
                [#local configSetTaskList += [ configSetId ] ]
                [#local cfnInitTasks += {
                    configSetId : cfnInitTask.Content
                }]
            [/#if]
        [/#if]
    [/#list]

    [#if cfnInitTasks?has_content]
        [#return
            {
                "AWS::CloudFormation::Init" : {
                    "configSets" : {
                        configSetName : configSetTaskList?sort
                    }
                } + cfnInitTasks
            }]
    [/#if]

    [#return {}]
[/#function]

[#function getUserDataFromComputeTasks computeTaskConfig ]

    [#local userDataConfig = []]
    [#list computeTaskConfig as id, task]
        [#if ((task[AWS_EC2_USERDATA_COMPUTE_TASK_CONFIG_TYPE])!{})?has_content ]
            [#local userDataConfig += [ task[AWS_EC2_USERDATA_COMPUTE_TASK_CONFIG_TYPE] ]]
        [/#if]
    [/#list]

    [#if userDataConfig?has_content]
        [#return {
            "Fn::Base64" : {
                "Fn::Join" : [
                    "\n",
                    asFlattenedArray(userDataConfig?sort_by("Priorty")?map( x -> x.Content ))
                ]
            }
        }]
    [/#if]
    [#return {}]
[/#function]

[#function getBlockDevices storageProfile]
    [#if storageProfile?is_hash ]
        [#if (storageProfile.Volumes)?has_content]
            [#local ebsVolumes = [] ]
            [#list storageProfile.Volumes?values as volume]
                [#if volume?is_hash]
                    [#local ebsVolumes +=
                        [
                            {
                                "DeviceName" : volume.Device,
                                "Ebs" : {
                                    "DeleteOnTermination" : true,
                                    "Encrypted" : false,
                                    "VolumeSize" : volume.Size,
                                    "VolumeType" : "gp2"
                                }
                            }
                        ]
                    ]
                [/#if]
            [/#list]
            [#return
                {
                    "BlockDeviceMappings" :
                        ebsVolumes +
                        [
                            {
                                "DeviceName" : "/dev/sdc",
                                "VirtualName" : "ephemeral0"
                            },
                            {
                                "DeviceName" : "/dev/sdt",
                                "VirtualName" : "ephemeral1"
                            }
                        ]
                }
            ]
        [/#if]
    [/#if]
    [#return {} ]
[/#function]

[#macro createEC2LaunchConfig id
    processorProfile
    storageProfile
    securityGroupId
    instanceProfileId
    resourceId
    imageId
    publicIP
    computeTaskConfig
    environmentId
    keyPairId
    sshFromProxy=sshFromProxySecurityGroup
    dependencies=""
    outputId=""
]

    [@cfResource
        id=id
        type="AWS::AutoScaling::LaunchConfiguration"
        properties=
            getBlockDevices(storageProfile) +
            {
                "KeyName" : getExistingReference(keyPairId, NAME_ATTRIBUTE_TYPE),
                "InstanceType": processorProfile.Processor,
                "ImageId" : imageId,
                "SecurityGroups" :
                    [
                        getReference(securityGroupId)
                    ] +
                    sshFromProxy?has_content?then(
                        [
                            sshFromProxy
                        ],
                        []
                    ),
                "IamInstanceProfile" : getReference(instanceProfileId),
                "AssociatePublicIpAddress" : publicIP,
                "UserData" : getUserDataFromComputeTasks(computeTaskConfig)
            }
        outputs={}
        outputId=outputId
        dependencies=dependencies
    /]
[/#macro]

[#macro createEc2AutoScaleGroup id
    tier
    computeTaskConfig
    launchConfigId
    processorProfile
    autoScalingConfig
    multiAZ
    tags
    networkResources
    scaleInProtection=false
    hibernate=false
    loadBalancers=[]
    targetGroups=[]
    dependencies=""
    outputId=""
]

    [#if processorProfile.MaxCount?has_content ]
        [#assign maxSize = processorProfile.MaxCount ]
    [#else]
        [#assign maxSize = processorProfile.MaxPerZone]
        [#if multiAZ]
            [#assign maxSize = maxSize * zones?size]
        [/#if]
    [/#if]

    [#if processorProfile.MinCount?has_content ]
        [#assign minSize = processorProfile.MinCount ]
    [#else]
        [#assign minSize = processorProfile.MinPerZone]
        [#if multiAZ]
            [#assign minSize = minSize * zones?size]
        [/#if]
    [/#if]

    [#if maxSize <= autoScalingConfig.MinUpdateInstances ]
        [#assign maxSize = maxSize + autoScalingConfig.MinUpdateInstances ]
    [/#if]

    [#assign desiredCapacity = processorProfile.DesiredCount!multiAZ?then(
                    processorProfile.DesiredPerZone * zones?size,
                    processorProfile.DesiredPerZone
    )]

    [#assign autoscalingMinUpdateInstances = autoScalingConfig.MinUpdateInstances ]
    [#if hibernate ]
        [#assign minSize = 0 ]
        [#assign desiredCapacity = 0 ]
        [#assign maxSize = 1]
        [#assign autoscalingMinUpdateInstances = 0 ]
    [/#if]

    [@cfResource
        id=id
        type="AWS::AutoScaling::AutoScalingGroup"
        metadata=getCFNInitFromComputeTasks(computeTaskConfig)
        properties=
            {
                "Cooldown" : autoScalingConfig.ActivityCooldown?c,
                "LaunchConfigurationName": getReference(launchConfigId)
            } +
            autoScalingConfig.DetailedMetrics?then(
                {
                    "MetricsCollection" : [
                        {
                            "Granularity" : "1Minute"
                        }
                    ]
                },
                {}
            ) +
            multiAZ?then(
                {
                    "MinSize": minSize,
                    "MaxSize": maxSize,
                    "DesiredCapacity": desiredCapacity,
                    "VPCZoneIdentifier": getSubnets(tier, networkResources)
                },
                {
                    "MinSize": minSize,
                    "MaxSize": maxSize,
                    "DesiredCapacity": desiredCapacity,
                    "VPCZoneIdentifier" : getSubnets(tier, networkResources)[0..0]
                }
            ) +
            attributeIfContent(
                "LoadBalancerNames",
                loadBalancers,
                loadBalancers
            ) +
            attributeIfContent(
                "TargetGroupARNs",
                targetGroups,
                targetGroups
            ) +
            attributeIfTrue(
                "NewInstancesProtectedFromScaleIn",
                scaleInProtection,
                true
            )
        tags=tags
        outputs=AWS_EC2_AUTO_SCALE_GROUP_OUTPUT_MAPPINGS
        outputId=outputId
        dependencies=dependencies
        updatePolicy=autoScalingConfig.ReplaceCluster?then(
            {
                "AutoScalingReplacingUpdate" : {
                    "WillReplace" : true
                }
            },
            {
                "AutoScalingRollingUpdate" : {
                    "WaitOnResourceSignals" : true,
                    "MinInstancesInService" : autoscalingMinUpdateInstances,
                    "MinSuccessfulInstancesPercent" : autoScalingConfig.MinSuccessInstances,
                    "PauseTime" : "PT" + autoScalingConfig.UpdatePauseTime,
                    "SuspendProcesses" : [
                        "HealthCheck",
                        "ReplaceUnhealthy",
                        "AZRebalance",
                        "AlarmNotification",
                        "ScheduledActions"
                    ]
                }
            }
        )
        creationPolicy={
                "ResourceSignal" : {
                    "Count" : desiredCapacity,
                    "Timeout" : "PT" + autoScalingConfig.StartupTimeout
                }
            }
    /]
[/#macro]

[#macro createEBSVolume id
    tags
    size
    zone
    volumeType
    encrypted
    kmsKeyId
    provisionedIops=0
    snapshotId=""
    dependencies=""
    outputId=""
]

    [@cfResource
        id=id
        type="AWS::EC2::Volume"
        properties={
            "AvailabilityZone" : zone.AWSZone,
            "VolumeType" : volumeType,
            "Size" : size
        } +
        (!(snapshotId?has_content) && encrypted)?then(
            {
                "Encrypted" : encrypted,
                "KmsKeyId" : getReference(kmsKeyId, ARN_ATTRIBUTE_TYPE)
            },
            {}
        ) +
        (volumeType == "io1")?then(
            {
                "Iops" : provisionedIops
            },
            {}
        ) +
        (snapshotId?has_content)?then(
            {
                "SnapshotId" : snapshotId
            },
            {}
        )
        tags=tags
        outputs=AWS_EC2_EBS_VOLUME_OUTPUT_MAPPINGS
        outputId=outputId
        dependencies=dependencies
    /]
[/#macro]

[#macro createEBSVolumeAttachment id
    device
    instanceId
    volumeId
]
    [@cfResource
        id=id
        type="AWS::EC2::VolumeAttachment"
        properties={
            "Device" : "/dev/" + device,
            "InstanceId" : getReference(instanceId),
            "VolumeId" : getReference(volumeId)
        }
        outputId=outputId
        dependencies=dependencies
    /]
[/#macro]


[#function getEC2AMIImageId imageConfiguration ec2ResourceId ]
    [#local imageId = ""]
    [#switch (imageConfiguration.Source)!"" ]
        [#case "Source:Reference"]
            [#local OSFamily = imageConfiguration["Source:Reference"]["OS"]]
            [#local OSType = imageConfiguration["Source:Reference"]["Type"]]

            [#local imageId = regionObject.AMIs[OSFamily][OSType]]
            [#break]

        [#case "aws:Source:AMI"]
            [#local imageId = imageConfiguration["aws:Source:AMI"]["ImageId"]]
            [#break]

        [#case "aws:Source:SSMParam"]

            [#local param = imageConfiguration["aws:Source:SSMParam"]["Name"]]
            [#local paramId = formatResourceId(AWS_EC2_AMI_PARAMETER_TYPE, ec2ResourceId) ]

            [@addCFNSSMEC2ImageParam
                id=paramId
                default=param
                description="AMI Image for EC2 Instance"
            /]

            [#local imageId = getReference(paramId)]
            [#break]

        [#default]
            [@fatal
                message="Invalid AMI Image Source"
                context={ "ec2Resoruce" : ec2ResourceId, "ImageConfiguration" : imageConfiguration }
            /]
    [/#switch]

    [#return imageId ]
[/#function]
