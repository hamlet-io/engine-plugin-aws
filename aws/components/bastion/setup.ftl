[#ftl]
[#macro aws_bastion_cf_deployment_generationcontract_segment occurrence ]
    [@addDefaultGenerationContract
        subsets="template"
        alternatives=[
            "primary",
            { "subset" : "template", "alternative" : "replace1"},
            { "subset" : "template", "alternative" : "replace2"}
        ]
    /]
[/#macro]

[#macro aws_bastion_cf_deployment_segment occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]
    [#local links = solution.Links ]

    [#local bastionRoleId = resources["role"].Id ]
    [#local bastionEIPId = resources["eip"].Id ]
    [#local bastionEIPName = resources["eip"].Name ]
    [#local bastionSecurityGroupToId = resources["securityGroupTo"].Id]
    [#local bastionSecurityGroupToName = resources["securityGroupTo"].Name]
    [#local bastionInstanceProfileId = resources["instanceProfile"].Id]
    [#local bastionAutoScaleGroupId = resources["autoScaleGroup"].Id]
    [#local bastionAutoScaleGroupName = resources["autoScaleGroup"].Name]
    [#local bastionLaunchConfigId = resources["launchConfig"].Id]
    [#local bastionLgId = resources["lg"].Id]
    [#local bastionLgName = resources["lg"].Name]
    [#local bastionOS = (solution.ComputeInstance.OperatingSystem.Family)!"linux"]

    [#local bastionType = occurrence.Core.Type]
    [#local configSetName = bastionType]

    [#local publicRouteTable = false ]

    [#local multiAZ = solution.MultiAZ ]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "OpsData", "AppData", "Encryption", "SSHKey" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local operationsBucket = getExistingReference(baselineComponentIds["OpsData"]) ]
    [#local dataBucket = getExistingReference(baselineComponentIds["AppData"])]
    [#local sshKeyPairId = baselineComponentIds["SSHKey"]!"HamletFatal: sshKeyPairId not found" ]
    [#local kmsKeyId = baselineComponentIds["Encryption"]]

    [#if deploymentSubsetRequired("eip", false) || deploymentSubsetRequired("bastion", true) ]
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

        [#local routeTableLinkTarget = getLinkTarget(occurrence, networkLink + { "RouteTable" : occurrenceNetwork.RouteTable }, false)]
        [#local routeTableConfiguration = routeTableLinkTarget.Configuration.Solution ]
        [#local publicRouteTable = routeTableConfiguration.Public ]
    [/#if]

    [#local storageProfile      = getStorage(occurrence, BASTION_COMPONENT_TYPE)]
    [#local logFileProfile      = getLogFileProfile(occurrence, BASTION_COMPONENT_TYPE)]
    [#local bootstrapProfile    = getBootstrapProfile(occurrence, BASTION_COMPONENT_TYPE)]
    [#local processorProfile    = getProcessor(occurrence, BASTION_COMPONENT_TYPE)]
    [#local networkProfile      = getNetworkProfile(occurrence)]
    [#local loggingProfile      = getLoggingProfile(occurrence)]

    [#local osPatching = mergeObjects(environmentObject.OSPatching, solution.ComputeInstance.OSPatching )]

    [#local sshActive = sshActive || solution.Active ]

    [#-- override sshActive on replace to ensure we bring the cluster down before a new instance --]
    [#if getCLODeploymentUnitAlternative() == "replace1" && sshActive ]
        [#local sshActive = false ]
    [/#if]

    [#local processorProfile += {
                "MaxCount" : 2,
                "MinCount" : sshActive?then(1,0),
                "DesiredCount" : sshActive?then(1,0)
    }]

    [#if sshEnabled && publicRouteTable ]
        [#if deploymentSubsetRequired("eip", true) &&
                isPartOfCurrentDeploymentUnit(bastionEIPId)]
            [@createEIP
                id=bastionEIPId
                tags=getOccurrenceCoreTags(
                        occurrence,
                        bastionEIPName
                    )
            /]
        [/#if]
    [#else]
        [#local bastionEIPId = ""]
    [/#if]

    [#local contextLinks = getLinkTargets(occurrence, links) ]
    [#local _context =
        {
            "DefaultEnvironment" : defaultEnvironment(occurrence, contextLinks, baselineLinks),
            "Environment" : {},
            "Links" : contextLinks,
            "BaselineLinks" : baselineLinks,
            "DefaultCoreVariables" : true,
            "DefaultEnvironmentVariables" : true,
            "DefaultBaselineVariables" : true,
            "DefaultLinkVariables" : true,
            "Policy" : iamStandardPolicies(occurrence, baselineComponentIds),
            "ManagedPolicy" : [],
            "ComputeTasks" : [],
            "Files" : {},
            "Directories" : {},
            "StorageProfile" : storageProfile,
            "LogFileProfile" : logFileProfile,
            "BootstrapProfile" : bootstrapProfile,
            "InstanceLogGroup" : bastionLgName,
            "InstanceOSPatching" : osPatching,
            "ElasticIPs" : asArray(bastionEIPId)?filter(x -> x?has_content)
        }
    ]

    [#-- Add in extension specifics including override of defaults --]
    [#local _context = invokeExtensions( occurrence, _context )]
    [#local linkPolicies = getLinkTargetsOutboundRoles(_context.Links) ]

    [#-- Add policies for external log group access --]
    [#list ((logFileProfile.LogFileGroups)![])?map(
                x -> (getReferenceData(LOGFILEGROUP_REFERENCE_TYPE)[x])!{}
            )?filter(
                x -> x?has_content && x.LogStore.Destination == "link" ) as logFileGroup ]

        [#local linkPolicies = combineEntities(
            linkPolicies,
            getLinkTargetsOutboundRoles(
                getLinkTargets(
                    occurrence,
                    {
                        "logstore": mergeObjects(
                            {"Name" : "logstore", "Id": "logstore"},
                            logFileGroup.LogStore.Link
                        )
                    }
                )
            ),
            APPEND_COMBINE_BEHAVIOUR
        )]
    [/#list]

    [#local environmentVariables = getFinalEnvironment(occurrence, _context).Environment ]

    [#local componentComputeTasks = resources["autoScaleGroup"].ComputeTasks]
    [#local userComputeTasks = solution.ComputeInstance.ComputeTasks.UserTasksRequired ]
    [#local computeTaskExtensions = solution.ComputeInstance.ComputeTasks.Extensions ]

    [#local computeTaskConfig = getOccurrenceComputeTaskConfig(occurrence, bastionAutoScaleGroupId, _context, computeTaskExtensions, componentComputeTasks, userComputeTasks)]

    [#if sshEnabled ]

        [#list _context.Links as linkId,linkTarget]
            [#local linkTargetCore = linkTarget.Core ]
            [#local linkTargetConfiguration = linkTarget.Configuration ]
            [#local linkTargetResources = linkTarget.State.Resources ]
            [#local linkTargetAttributes = linkTarget.State.Attributes ]
            [#local linkTargetRoles = linkTarget.State.Roles]

            [#if deploymentSubsetRequired("bastion", true)]
                [@createSecurityGroupRulesFromLink
                    occurrence=occurrence
                    groupId=bastionSecurityGroupToId
                    linkTarget=linkTarget
                    inboundPorts=solution.ComputeInstance.ManagementPorts
                    networkProfile=networkProfile
                /]
            [/#if]
        [/#list]

        [#if deploymentSubsetRequired("iam", true) &&
                isPartOfCurrentDeploymentUnit(bastionRoleId)]
            [@createRole
                id=bastionRoleId
                trustedServices=["ec2.amazonaws.com" ]
                policies=
                    [
                        getPolicyDocument(
                            ec2AutoScaleGroupLifecyclePermission(bastionAutoScaleGroupName) +
                            ec2IPAddressUpdatePermission() +
                            ec2ReadTagsPermission() +
                            s3ListPermission(getCodeBucket()) +
                            s3ReadPermission(getCodeBucket()) +
                            s3AccountEncryptionReadPermission(
                                getCodeBucket(),
                                "*",
                                getCodeBucketRegion()
                            ) +
                            cwMetricsProducePermission("CWAgent") +
                            cwLogsProducePermission(bastionLgName),
                            "basic"
                        ),
                        getPolicyDocument(
                            ssmSessionManagerPermission(bastionOS),
                            "ssm"
                        )
                    ] +
                    arrayIfContent(
                        [getPolicyDocument(_context.Policy, "fragment")],
                        _context.Policy) +
                    arrayIfContent(
                        [getPolicyDocument(linkPolicies, "links")],
                        linkPolicies)
                managedArns=_context.ManagedPolicy
                tags=getOccurrenceCoreTags(occurrence)
            /]
        [/#if]


        [@setupLogGroup
            occurrence=occurrence
            logGroupId=bastionLgId
            logGroupName=bastionLgName
            loggingProfile=loggingProfile
            kmsKeyId=kmsKeyId
        /]

        [#if deploymentSubsetRequired("bastion", true)]
            [@createSecurityGroup
                id=bastionSecurityGroupToId
                name=bastionSecurityGroupToName
                vpcId=vpcId
                description="Security Group for inbound SSH to the SSH Proxy"
                occurrence=occurrence
            /]

            [@createSecurityGroupRulesFromNetworkProfile
                occurrence=occurrence
                groupId=bastionSecurityGroupToId
                networkProfile=networkProfile
                inboundPorts=solution.ComputeInstance.ManagementPorts
            /]

            [#local bastionSSHNetworkRule = {
                        "Ports" : solution.ComputeInstance.ManagementPorts,
                        "IPAddressGroups" :
                            sshEnabled?then(
                                combineEntities(
                                    (segmentObject.Bastion.IPAddressGroups)!(segmentObject.IPAddressGroups)![],
                                    (solution.IPAddressGroups)![],
                                    UNIQUE_COMBINE_BEHAVIOUR
                                ),
                                []
                            ),
                        "Description" : "Bastion Access Groups"
            }]

            [@createSecurityGroupIngressFromNetworkRule
                occurrence=occurrence
                groupId=bastionSecurityGroupToId
                networkRule=bastionSSHNetworkRule
            /]

            [@cfResource
                id=bastionInstanceProfileId
                type="AWS::IAM::InstanceProfile"
                properties=
                    {
                        "Path" : "/",
                        "Roles" : [ getReference(bastionRoleId) ]
                    }
                outputs={}
            /]

            [@createEc2AutoScaleGroup
                id=bastionAutoScaleGroupId
                tier=core.Tier
                computeTaskConfig=computeTaskConfig
                launchConfigId=bastionLaunchConfigId
                processorProfile=processorProfile
                autoScalingConfig=solution.AutoScaling
                multiAZ=multiAZ
                tags=getOccurrenceCoreTags(
                        occurrence,
                        bastionAutoScaleGroupName
                        "",
                        true
                    )
                networkResources=networkResources
            /]

            [@createEC2LaunchConfig
                id=bastionLaunchConfigId
                processorProfile=processorProfile
                storageProfile=_context.StorageProfile
                securityGroupId=bastionSecurityGroupToId
                instanceProfileId=bastionInstanceProfileId
                resourceId=bastionAutoScaleGroupId
                imageId=getEC2AMIImageId(solution.ComputeInstance.Image, bastionLaunchConfigId)
                publicIP=publicRouteTable
                computeTaskConfig=computeTaskConfig
                environmentId=environmentId
                sshFromProxy=[]
                keyPairId=sshKeyPairId
            /]
        [/#if]
    [/#if]
[/#macro]
