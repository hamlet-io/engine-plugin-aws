[#ftl]
[#macro aws_bastion_cf_deployment_generationcontract_segment occurrence ]
    [@addDefaultGenerationContract subsets="template" /]
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

    [#local bastionOS = solution.OS ]
    [#local bastionType = occurrence.Core.Type]
    [#local configSetName = bastionType]

    [#local publicRouteTable = false ]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "OpsData", "AppData", "Encryption", "SSHKey" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local operationsBucket = getExistingReference(baselineComponentIds["OpsData"]) ]
    [#local dataBucket = getExistingReference(baselineComponentIds["AppData"])]
    [#local sshKeyPairId = baselineComponentIds["SSHKey"]!"HamletFatal: sshKeyPairId not found" ]

    [#switch bastionOS ]
        [#case "linux" ]
            [#local imageId = regionObject.AMIs.Centos.EC2]
            [#break]
    [/#switch]

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

    [#local storageProfile = getStorage(occurrence, BASTION_COMPONENT_TYPE)]
    [#local logFileProfile = getLogFileProfile(occurrence, BASTION_COMPONENT_TYPE)]
    [#local bootstrapProfile = getBootstrapProfile(occurrence, BASTION_COMPONENT_TYPE)]
    [#local networkProfile = getNetworkProfile(solution.Profiles.Network)]
    [#local loggingProfile = getLoggingProfile(solution.Profiles.Logging)]

    [#local processorProfile = getProcessor(occurrence, "bastion")]

    [#local processorProfile += {
                "MaxCount" : 2,
                "MinCount" : sshActive?then(1,0),
                "DesiredCount" : sshActive?then(1,0)
    }]

    [#local osPatching = mergeObjects(solution.OSPatching, environmentObject.OSPatching )]

    [#local configSets =
            getInitConfigDirectories() +
            getInitConfigBootstrap(occurrence, operationsBucket, dataBucket) +
            osPatching.Enabled?then(
                getInitConfigOSPatching(
                    osPatching.Schedule,
                    osPatching.SecurityOnly
                ),
                {}
            )]

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
            "Policy" : standardPolicies(occurrence, baselineComponentIds),
            "ManagedPolicy" : [],
            "Files" : {},
            "Directories" : {}
        }
    ]

    [#-- Add in extension specifics including override of defaults --]
    [#local _context = invokeExtensions( occurrence, _context )]

    [#local environmentVariables = getFinalEnvironment(occurrence, _context).Environment ]
    [#local linkPolicies = getLinkTargetsOutboundRoles(_context.Links) ]

    [#local configSets +=
        getInitConfigEnvFacts(environmentVariables, false) +
        getInitConfigDirsFiles(_context.Files, _context.Directories) ]

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
                    inboundPorts=[ "ssh" ]
                    networkProfile=networkProfile
                /]
            [/#if]


            [#switch linkTargetCore.Type]
                [#case EFS_COMPONENT_TYPE ]
                [#case EFS_MOUNT_COMPONENT_TYPE]
                    [#local configSets +=
                        getInitConfigEFSMount(
                            linkTargetCore.Id,
                            linkTargetAttributes.EFS,
                            linkTargetAttributes.DIRECTORY,
                            linkId,
                            (linkTargetAttributes.ACCESS_POINT_ID)!""
                        )]
                    [#break]
                [#case USER_COMPONENT_TYPE]
                    [#local SSHPublicKeys = linkTargetConfiguration.Solution.SSHPublicKeys ]
                    [#local linkEnvironment = linkTargetConfiguration.Environment.General ]
                    [#local configSets +=
                        getInitConfigSSHPublicKeys(
                            SSHPublicKeys, linkEnvironment
                        )]
                    [#break]
            [/#switch]
        [/#list]

        [#if deploymentSubsetRequired("iam", true) &&
                isPartOfCurrentDeploymentUnit(bastionRoleId)]
            [@createRole
                id=bastionRoleId
                trustedServices=["ec2.amazonaws.com" ]
                policies=
                    [
                        getPolicyDocument(
                            ec2IPAddressUpdatePermission() +
                            s3ListPermission(codeBucket) +
                            s3ReadPermission(codeBucket) +
                            s3AccountEncryptionReadPermission(
                                codeBucket,
                                "*",
                                codeBucketRegion
                            ) +
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
            /]
        [/#if]

        [#if publicRouteTable ]
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

            [#local configSets +=
                getInitConfigEIPAllocation(
                    getReference(
                        bastionEIPId,
                        ALLOCATION_ATTRIBUTE_TYPE
                    ))]
        [/#if]

        [@setupLogGroup
            occurrence=occurrence
            logGroupId=bastionLgId
            logGroupName=bastionLgName
            loggingProfile=loggingProfile
        /]

        [#local configSets +=
            getInitConfigLogAgent(
                logFileProfile,
                bastionLgName
            )]

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
                inboundPorts=[ "ssh" ]
            /]

            [#local bastionSSHNetworkRule = {
                        "Ports" : [ "ssh" ],
                        "IPAddressGroups" :
                            sshEnabled?then(
                                (segmentObject.Bastion.IPAddressGroups)!(segmentObject.IPAddressGroups)![],
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
                configSetName=configSetName
                configSets=configSets
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
                storageProfile=storageProfile
                securityGroupId=bastionSecurityGroupToId
                instanceProfileId=bastionInstanceProfileId
                resourceId=bastionAutoScaleGroupId
                imageId=imageId
                publicIP=publicRouteTable
                configSet=configSetName
                enableCfnSignal=true
                environmentId=environmentId
                sshFromProxy=[]
                keyPairId=sshKeyPairId
            /]
        [/#if]
    [/#if]
[/#macro]
