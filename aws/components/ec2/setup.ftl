[#ftl]
[#macro aws_ec2_cf_deployment_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract subsets="template" /]
[/#macro]

[#macro aws_ec2_cf_deployment_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]
    [#local resources = occurrence.State.Resources]
    [#local zoneResources = occurrence.State.Resources.Zones]
    [#local links = solution.Links ]

    [#local fixedIP = solution.FixedIP]
    [#local dockerHost = solution.DockerHost]

    [#local ec2SecurityGroupId     = resources["sg"].Id]
    [#local ec2SecurityGroupName   = resources["sg"].Name]
    [#local ec2SecurityGroupPorts  = resources["sg"].Ports ]
    [#local ec2RoleId              = resources["ec2Role"].Id]
    [#local ec2InstanceProfileId   = resources["instanceProfile"].Id]
    [#local ec2LogGroupId          = resources["lg"].Id]
    [#local ec2LogGroupName        = resources["lg"].Name]

    [#local processorProfile       = getProcessor(occurrence, "EC2")]
    [#local storageProfile         = getStorage(occurrence, "EC2")]
    [#local logFileProfile         = getLogFileProfile(occurrence, "EC2")]
    [#local bootstrapProfile       = getBootstrapProfile(occurrence, "EC2")]
    [#local networkProfile         = getNetworkProfile(solution.Profiles.Network)]
    [#local loggingProfile         = getLoggingProfile(solution.Profiles.Logging)]

    [#local osPatching = mergeObjects(solution.ComputeInstance.OSPatching, environmentObject.OSPatching )]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "OpsData", "AppData", "Encryption", "SSHKey" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local operationsBucket = getExistingReference(baselineComponentIds["OpsData"]) ]
    [#local dataBucket = getExistingReference(baselineComponentIds["AppData"])]
    [#local sshKeyPairId = baselineComponentIds["SSHKey"]!"HamletFatal: sshKeyPairId not found" ]

    [#local occurrenceNetwork = getOccurrenceNetwork(occurrence) ]
    [#local networkLink = occurrenceNetwork.Link!{} ]

    [#local networkLinkTarget = getLinkTarget(occurrence, networkLink ) ]

    [#if ! networkLinkTarget?has_content ]
        [@fatal message="Network could not be found" context=networkLink /]
        [#return]
    [/#if]

    [#local networkConfiguration = networkLinkTarget.Configuration.Solution]
    [#local networkResources = networkLinkTarget.State.Resources ]

    [#local vpcId = networkResources["vpc"].Id ]

    [#local routeTableLinkTarget = getLinkTarget(occurrence, networkLink + { "RouteTable" : occurrenceNetwork.RouteTable })]
    [#local routeTableConfiguration = routeTableLinkTarget.Configuration.Solution ]
    [#local publicRouteTable = routeTableConfiguration.Public ]

    [#local targetGroupRegistrations = {}]
    [#local targetGroupPermission = false ]

    [#local environmentVariables = {}]

    [#local efsMountPoints = {}]

    [#local componentDependencies = []]
    [#local ingressRules = []]

    [#list solution.Ports?values as port ]
        [#if port.LB.Configured]
            [#local lbLink = getLBLink(occurrence, port)]
            [#if isDuplicateLink(links, lbLink) ]
                [@fatal
                    message="Duplicate Link Name"
                    context=links
                    detail=lbLink /]
                [#continue]
            [/#if]
            [#local links += lbLink]
        [#else]
            [#local ingressRules +=
                [{
                    "Ports" : port.Name,
                    "IPAddressGroups" : port.IPAddressGroups
                }]]
        [/#if]
    [/#list]

    [#local contextLinks = getLinkTargets(occurrence, links) ]
    [#local _context =
        {
            "DefaultEnvironment" : defaultEnvironment(occurrence, contextLinks, baselineLinks),
            "Environment" : {},
            "Links" : contextLinks,
            "BaselineLinks" : baselineLinks,
            "DefaultCoreVariables" : true,
            "DefaultEnvironmentVariables" : false,
            "DefaultLinkVariables" : true,
            "DefaultBaselineVariables" : true,
            "Policy" : standardPolicies(occurrence, baselineComponentIds),
            "ManagedPolicy" : [],
            "ComputeTasks" : [],
            "Files" : {},
            "Directories" : {},
            "DataVolumes" : {},
            "VolumeMounts" : {},
            "StorageProfile" : storageProfile,
            "LogFileProfile" : logFileProfile,
            "BootstrapProfile" : bootstrapProfile,
            "InstanceLogGroup" : ec2LogGroupName,
            "InstanceOSPatching" : osPatching
        }
    ]

    [#local _context = invokeExtensions( occurrence, _context )]

    [#local environmentVariables += getFinalEnvironment(occurrence, _context ).Environment ]

    [#local configSetName = occurrence.Core.Type]

    [#local userComputeTasks = solution.ComputeInstance.ComputeTasks.UserTasksRequired ]
    [#local computeTaskExtensions = solution.ComputeInstance.ComputeTasks.Extensions ]

    [#list links as linkId,link]
        [#local linkTarget = getLinkTarget(occurrence, link) ]

        [@debug message="Link Target" context=linkTarget enabled=false /]

        [#if !linkTarget?has_content]
            [#continue]
        [/#if]

        [#local linkTargetCore = linkTarget.Core ]
        [#local linkTargetConfiguration = linkTarget.Configuration ]
        [#local linkTargetResources = linkTarget.State.Resources ]
        [#local linkTargetAttributes = linkTarget.State.Attributes ]

        [#if deploymentSubsetRequired(EC2_COMPONENT_TYPE, true)]
            [@createSecurityGroupRulesFromLink
                occurrence=occurrence
                groupId=ec2SecurityGroupId
                linkTarget=linkTarget
                inboundPorts=ec2SecurityGroupPorts
                networkProfile=networkProfile
            /]
        [/#if]

        [#local sourceSecurityGroupIds = []]
        [#local sourceIPAddressGroups = [] ]

        [#switch linkTargetCore.Type]
            [#case LB_PORT_COMPONENT_TYPE]
                [#local targetGroupPermission = true]
                [#local destinationPort = linkTargetAttributes["DESTINATION_PORT"]]

                [#switch linkTargetAttributes["ENGINE"] ]
                    [#case "application" ]
                    [#case "classic"]
                        [#local sourceSecurityGroupIds += [ linkTargetResources["sg"].Id ] ]
                        [#break]
                    [#case "network" ]
                        [#local sourceIPAddressGroups = linkTargetConfiguration.IPAddressGroups + [ "_localnet" ] ]
                        [#break]
                [/#switch]

        [#case DATAVOLUME_COMPONENT_TYPE]
                [#local linkVolumeResources = {}]
                [#list linkTargetResources["Zones"] as zoneId, linkZoneResources ]
                    [#local linkVolumeResources += {
                        zoneId : {
                            "VolumeId" : linkZoneResources["ebsVolume"].Id
                        }
                    }]
                [/#list]
                [#local _context +=
                    {
                        "DataVolumes" :
                            (_context.DataVolumes!{}) +
                            {
                                linkId : linkVolumeResources
                            }
                    }]
                [#break]
        [/#switch]

        [#if deploymentSubsetRequired(EC2_COMPONENT_TYPE, true)]

            [#local securityGroupCIDRs = getGroupCIDRs(sourceIPAddressGroups, true, occurrence)]
            [#list securityGroupCIDRs as cidr ]

                [@createSecurityGroupIngress
                    id=
                        formatDependentSecurityGroupIngressId(
                            ec2SecurityGroupId,
                            link.Id,
                            destinationPort,
                            replaceAlphaNumericOnly(cidr)
                        )
                    port=destinationPort
                    cidr=cidr
                    groupId=ec2SecurityGroupId
            /]
            [/#list]

            [#list sourceSecurityGroupIds as group ]
                [@createSecurityGroupIngress
                    id=
                        formatDependentSecurityGroupIngressId(
                            ec2SecurityGroupId,
                            link.Id,
                            destinationPort
                        )
                    port=destinationPort
                    group=group
                    groupId=ec2SecurityGroupId
                /]
            [/#list]
        [/#if]
    [/#list]

    [#if deploymentSubsetRequired("iam", true) &&
            isPartOfCurrentDeploymentUnit(ec2RoleId)]

        [#local linkPolicies = getLinkTargetsOutboundRoles(_context.Links) ]

        [@createRole
            id=ec2RoleId
            trustedServices=["ec2.amazonaws.com" ]
            managedArns=
                _context.ManagedPolicy
            policies=
                [
                    getPolicyDocument(
                        s3ListPermission(codeBucket) +
                        s3ReadPermission(codeBucket) +
                        s3AccountEncryptionReadPermission(
                            codeBucket,
                            "*",
                            codeBucketRegion
                        ) +
                        s3ListPermission(operationsBucket) +
                        s3WritePermission(operationsBucket, "DOCKERLogs") +
                        s3WritePermission(operationsBucket, "Backups") +
                        cwLogsProducePermission(ec2LogGroupName) +
                        ec2EBSVolumeReadPermission(),
                        "basic"
                    ),
                    getPolicyDocument(
                        ssmSessionManagerPermission(),
                        "ssm"
                    )
                ] + targetGroupPermission?then(
                    [
                        getPolicyDocument(
                            lbRegisterTargetPermission(),
                            "loadbalancing")
                    ],
                    []
                ) +
                arrayIfContent(
                    [getPolicyDocument(linkPolicies, "links")],
                    linkPolicies) +
                arrayIfContent(
                    [getPolicyDocument(_context.Policy, "extension")],
                    _context.Policy)
        /]
    [/#if]

    [@setupLogGroup
        occurrence=occurrence
        logGroupId=ec2LogGroupId
        logGroupName=ec2LogGroupName
        loggingProfile=loggingProfile
    /]

    [#if deploymentSubsetRequired(EC2_COMPONENT_TYPE, true)]

        [@createSecurityGroup
            id=ec2SecurityGroupId
            name=ec2SecurityGroupName
            vpcId=vpcId
            occurrence=occurrence
        /]

        [@createSecurityGroupRulesFromNetworkProfile
            occurrence=occurrence
            groupId=ec2SecurityGroupId
            networkProfile=networkProfile
            inboundPorts=ec2SecurityGroupPorts
        /]

        [#list ingressRules as ingressRule ]
            [@createSecurityGroupIngressFromNetworkRule
                occurrence=occurrence
                groupId=ec2SecurityGroupId
                networkRule=ingressRule
            /]
        [/#list]

        [@cfResource
            id=ec2InstanceProfileId
            type="AWS::IAM::InstanceProfile"
            properties=
                {
                    "Path" : "/",
                    "Roles" : [getReference(ec2RoleId)]
                }
            outputs={}
        /]

        [#list zones as zone]
            [#if multiAZ || (zones[0].Id = zone.Id)]
                [#local zoneEc2InstanceId          = zoneResources[zone.Id]["ec2Instance"].Id ]
                [#local zoneEc2InstanceName        = zoneResources[zone.Id]["ec2Instance"].Name ]
                [#local zoneEc2ComputeTasks        = zoneResources[zone.Id]["ec2Instance"].ComputeTasks]
                [#local zoneEc2ENIId               = zoneResources[zone.Id]["ec2ENI"].Id ]
                [#local zoneEc2EIPId               = zoneResources[zone.Id]["ec2EIP"].Id]
                [#local zoneEc2EIPName             = zoneResources[zone.Id]["ec2EIP"].Id]
                [#local zoneEc2EIPAssociationId    = zoneResources[zone.Id]["ec2EIPAssociation"].Id]
                [#local zoneWaitHandleId           = zoneResources[zone.Id]["waitHandle"].Id ]
                [#local zoneWaitConditionId        = zoneResources[zone.Id]["waitCondition"].Id]

                [#local imageId = getEC2AMIImageId(solution.ComputeInstance.Image, zoneEc2InstanceId)]

                [#local zoneContext = _context + { "WaitHandleId" : zoneWaitHandleId }]
                [#local computeTaskConfig = getOccurrenceComputeTaskConfig(occurrence, zoneEc2InstanceId, zoneContext, computeTaskExtensions, zoneEc2ComputeTasks, userComputeTasks)]

                [@createCFNWait
                    conditionId=zoneWaitConditionId
                    handleId=zoneWaitHandleId
                    signalCount=1
                    waitDependencies=[ zoneEc2InstanceId ]
                /]

                [@cfResource
                    id=zoneEc2InstanceId
                    type="AWS::EC2::Instance"
                    metadata=getCFNInitFromComputeTasks(computeTaskConfig)
                    properties=
                        getBlockDevices(storageProfile) +
                        {
                            "DisableApiTermination" : false,
                            "EbsOptimized" : false,
                            "IamInstanceProfile" : { "Ref" : ec2InstanceProfileId },
                            "InstanceInitiatedShutdownBehavior" : "stop",
                            "InstanceType": processorProfile.Processor,
                            "KeyName": getExistingReference(sshKeyPairId, NAME_ATTRIBUTE_TYPE),
                            "Monitoring" : false,
                            "ImageId": imageId,
                            "NetworkInterfaces" : [
                                {
                                    "DeviceIndex" : "0",
                                    "NetworkInterfaceId" : getReference(zoneEc2ENIId)
                                }
                            ],
                            "UserData" : getUserDataFromComputeTasks(computeTaskConfig)
                        }
                    tags=
                        getOccurrenceCoreTags(
                            occurrence,
                            formatComponentFullName(core.Tier, core.Component, zone),
                            zone)
                    outputs={}
                    dependencies=[zoneEc2ENIId] +
                        componentDependencies +
                        fixedIP?then(
                            [zoneEc2EIPAssociationId],
                            [])
                    creationPolicy={
                        "ResourceSignal" : {
                            "Count" : 1,
                            "Timeout" : "PT5M"
                        }
                    }
                /]

                [@cfResource
                    id=zoneEc2ENIId
                    type="AWS::EC2::NetworkInterface"
                    properties=
                        {
                            "Description" : "eth0",
                            "SubnetId" : getSubnets(core.Tier, networkResources, zone.Id)[0],
                            "SourceDestCheck" : true,
                            "GroupSet" :
                                [getReference(ec2SecurityGroupId)] +
                                sshFromProxySecurityGroup?has_content?then(
                                    [sshFromProxySecurityGroup],
                                    []
                                )
                        }
                    tags=
                        getOccurrenceCoreTags(
                            occurrence,
                            formatComponentFullName(core.Tier, core.Component, zone, "eth0"),
                            zone)
                    outputs={}
                /]

                [#if fixedIP || publicRouteTable]
                    [@createEIP
                        id=zoneEc2EIPId
                        dependencies=[zoneEc2ENIId]
                        tags=getOccurrenceCoreTags(
                            occurrence,
                            zoneEc2EIPName
                        )
                    /]

                    [@cfResource
                        id=zoneEc2EIPAssociationId
                        type="AWS::EC2::EIPAssociation"
                        properties=
                            {
                                "AllocationId" : getReference(zoneEc2EIPId, ALLOCATION_ATTRIBUTE_TYPE),
                                "NetworkInterfaceId" : getReference(zoneEc2ENIId)
                            }
                        dependencies=[zoneEc2EIPId]
                        outputs={}
                    /]
                [/#if]
            [/#if]
        [/#list]
    [/#if]
[/#macro]
