[#ftl]
[#macro aws_fileshare_cf_deployment_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract subsets="template" /]
[/#macro]

[#macro aws_fileshare_cf_deployment_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]
    [#local resources = occurrence.State.Resources]
    [#local zoneResources = (occurrence.State.Resources.Zones)!{}]

    [#local engine = solution.Engine ]

    [#local networkLink = (getOccurrenceNetwork(occurrence).Link)!{} ]
    [#local networkLinkTarget = getLinkTarget(occurrence, networkLink ) ]

    [#if ! networkLinkTarget?has_content ]
        [@fatal message="Network could not be found" context=networkLink /]
        [#return]
    [/#if]

    [#local networkConfiguration = networkLinkTarget.Configuration.Solution]
    [#local networkResources = networkLinkTarget.State.Resources ]

    [#local vpcId = networkResources["vpc"].Id ]

    [#local loggingProfile      = getLoggingProfile(occurrence)]

    [#switch engine ]
        [#case "NFS" ]
            [#local fileshareId            = resources["efs"].Id]
            [#local fileshareName          = resources["efs"].Name]
            [#break]

        [#case "SMB"]
            [#local fileshareId            = resources["fsx"].Id]
            [#local fileshareName          = resources["fsx"].Name]
            [#break]
    [/#switch]

    [#local fileshareSecurityGroupId     = resources["sg"].Id]
    [#local fileshareSecurityGroupName   = resources["sg"].Name]
    [#local fileshareSecurityGroupPorts  = resources["sg"].Ports]

    [#local networkProfile = getNetworkProfile(occurrence)]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "Encryption"] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local cmkKeyId = baselineComponentIds["Encryption" ]]

    [#local directoryId = []]
    [#local directoryDomainName = []]

    [#list ((solution.Links)!{})?values as link]
        [#if link?is_hash]
            [#local linkTarget = getLinkTarget(occurrence, link) ]

            [@debug message="Link Target" context=linkTarget enabled=false /]

            [#if !linkTarget?has_content]
                [#continue]
            [/#if]

            [#local linkTargetCore = linkTarget.Core ]
            [#local linkTargetConfiguration = linkTarget.Configuration ]
            [#local linkTargetResources = linkTarget.State.Resources ]
            [#local linkTargetAttributes = linkTarget.State.Attributes ]

            [#if linkTargetCore.Type == DIRECTORY_COMPONENT_TYPE ]
                [#switch linkTargetAttributes["ENGINE"] ]
                    [#case "ActiveDirectory"]
                    [#case "aws:ADConnector"]
                        [#local directoryId += [ linkTargetAttributes["DOMAIN_ID"] ]]
                        [#local directoryDomainName += [ linkTargetAttributes["FQDN"]]]
                        [#break]
                [/#switch]

            [/#if]

            [#if deploymentSubsetRequired(FILESHARE_COMPONENT_TYPE, true)]
                [@createSecurityGroupRulesFromLink
                    occurrence=occurrence
                    groupId=fileshareSecurityGroupId
                    linkTarget=linkTarget
                    inboundPorts=fileshareSecurityGroupPorts
                    networkProfile=networkProfile
                /]
            [/#if]
        [/#if]
    [/#list]


    [#local fsxWindowsConfiguration = {}]

    [#switch engine ]
        [#case "SMB"]
            [#if ! directoryId?has_content ]
                [@fatal
                    message="An active directory domain id is required when using the SMB engine"
                    detail="Create a managed AD or an AD Connector for your existing AD environment and link to it from this component"
                    context={
                        "Id" : core.RawId,
                        "Links" : solution.Links
                    }
                /]
                [#return]
            [/#if]

            [#if directoryId?size > 1 ]
                [@fatal
                    message="Multiple directory links found"
                    detail="Only one directory can be be used for an SMB file share"
                    context={
                        "Id" : core.RawId,
                        "Links" : solution.Links
                    }
                /]
                [#return]
            [/#if]

            [#if directoryDomainName?has_content && directoryDomainName[0]?length > 47  ]
                [@fatal
                    message="Domain name for directory is too long"
                    detail="FSx doesn't support domain names longer than 47 chars"
                    context={
                        "Id" : core.RawId,
                        "DomainName" : directoryDomainName[0],
                        "Id" : directoryId,
                        "DetailLink" : "https://docs.aws.amazon.com/fsx/latest/WindowsGuide/fsx-aws-managed-ad.html"
                    }
                /]
            [/#if]

            [#local fsxWindowsConfiguration = getFSXWindowsConfiguration(
                    directoryId[0],
                    solution["aws:ThroughputCapacity"],
                    [],
                    solution.MaintenanceWindow,
                    solution.Backup.RetentionPeriod,
                    multiAZ,
                    getSubnets(core.Tier, networkResources)
                )]
            [#break]
    [/#switch]

    [#if deploymentSubsetRequired(FILESHARE_COMPONENT_TYPE, true) ]

        [@createSecurityGroup
            id=fileshareSecurityGroupId
            name=fileshareSecurityGroupName
            vpcId=vpcId
            occurrence=occurrence
        /]

        [@createSecurityGroupRulesFromNetworkProfile
            occurrence=occurrence
            groupId=fileshareSecurityGroupId
            networkProfile=networkProfile
            inboundPorts=fileshareSecurityGroupPorts
        /]

        [#local ingressNetworkRule = {
                "Ports" : fileshareSecurityGroupPorts,
                "IPAddressGroups" : solution.IPAddressGroups
        }]

        [@createSecurityGroupIngressFromNetworkRule
            occurrence=occurrence
            groupId=fileshareSecurityGroupId
            networkRule=ingressNetworkRule
        /]

        [#switch engine ]
            [#case "NFS"]
                [@createEFS
                    id=fileshareId
                    tags=getOccurrenceCoreTags(occurrence, fileshareName, "", false)
                    encrypted=solution.Encrypted
                    kmsKeyId=cmkKeyId
                    iamRequired=solution["aws:IAMRequired"]
                    resourcePolicyStatements=
                        getPolicyStatement(
                            [
                                "elasticfilesystem:ClientMount"
                            ],
                            "",
                            {
                                "AWS" : {
                                    "Fn::Join": [
                                        "",
                                        [
                                            "arn:aws:iam::",
                                            {
                                                "Ref": "AWS::AccountId"
                                            },
                                            ":root"
                                        ]
                                    ]
                                }
                            }
                        )
                /]

                [#list getZones() as zone ]
                    [#local zoneEfsMountTargetId   = zoneResources[zone.Id]["efsMountTarget"].Id]
                    [@createEFSMountTarget
                        id=zoneEfsMountTargetId
                        subnet=getSubnets(core.Tier, networkResources, zone.Id, true, false)
                        efsId=fileshareId
                        securityGroups=fileshareSecurityGroupId
                    /]
                [/#list]

                [#break]

            [#case "SMB"]
                [@createFSXFileSystem
                    id=fileshareId
                    fsType=engine
                    subnets=multiAZ?then(
                        getSubnets(core.Tier, networkResources),
                        [ getSubnets(core.Tier, networkResources)[0] ]
                    )
                    securityGroupIds=[fileshareSecurityGroupId]
                    encrypted=false
                    kmsKeyId=cmkKeyId
                    storageCapacity=solution.Size
                    windowsConfiguration=fsxWindowsConfiguration
                    tags=getOccurrenceCoreTags(occurrence, fileshareName, "", false)
                /]
                [#break]
        [/#switch]
    [/#if]

    [#-- Subcomponents --]
    [#list occurrence.Occurrences![] as subOccurrence]

        [#local subCore = subOccurrence.Core ]
        [#local subSolution = subOccurrence.Configuration.Solution ]
        [#local subResources = subOccurrence.State.Resources ]

        [#if subCore.Type == FILESHARE_MOUNT_COMPONENT_TYPE ]

            [#switch engine ]
                [#case "NFS"]

                    [#local efsAccessPointId = subResources["accessPoint"].Id ]
                    [#local efsAccessPointName = subResources["accessPoint"].Name ]

                    [#if deploymentSubsetRequired(FILESHARE_COMPONENT_TYPE, true) ]
                        [@createEFSAccessPoint
                            id=efsAccessPointId
                            efsId=fileshareId
                            tags=getOccurrenceCoreTags(occurrence, efsAccessPointName, "", false)
                            overidePermissions=subSolution.Ownership.Enforced
                            chroot=subSolution.chroot
                            uid=subSolution.Ownership.UID
                            gid=subSolution.Ownership.GID
                            secondaryGids=subSolution.Ownership.SecondaryGIDS
                            permissions=subSolution.Ownership.Permissions
                            rootPath=subSolution.Directory
                        /]
                    [/#if]
                    [#break]

                [#default]
                    [@fatal
                        message="Mounts not supported for this engine"
                        detail="Mounts are not managed as part of the deployment of this engine"
                        context={
                            "Component" : occurrence.Core.RawId,
                            "Mount" : subOccurrence.Core.RawId,
                            "Engine" : engine
                        }
                    /]
            [/#switch]
        [/#if]
    [/#list]
[/#macro]
