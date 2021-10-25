[#ftl]
[#macro aws_efs_cf_deployment_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract subsets="template" /]
[/#macro]

[#macro aws_efs_cf_deployment_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]
    [#local resources = occurrence.State.Resources]
    [#local zoneResources = occurrence.State.Resources.Zones]

    [#local networkLink = getOccurrenceNetwork(occurrence).Link!{} ]

    [#local networkLinkTarget = getLinkTarget(occurrence, networkLink ) ]

    [#if ! networkLinkTarget?has_content ]
        [@fatal message="Network could not be found" context=networkLink /]
        [#return]
    [/#if]

    [#local networkConfiguration = networkLinkTarget.Configuration.Solution]
    [#local networkResources = networkLinkTarget.State.Resources ]

    [#local vpcId = networkResources["vpc"].Id ]

    [#local efsPort = 2049]

    [#local efsId                  = resources["efs"].Id]
    [#local efsFullName            = resources["efs"].Name]
    [#local efsSecurityGroupId     = resources["sg"].Id]
    [#local efsSecurityGroupName   = resources["sg"].Name]
    [#local efsSecurityGroupPorts  = resources["sg"].Ports]

    [#local efsSecurityGroupIngressId = formatDependentSecurityGroupIngressId(
                                            efsSecurityGroupId,
                                            efsPort)]

    [#local networkProfile = getNetworkProfile(occurrence)]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "Encryption"] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local cmkKeyId = baselineComponentIds["Encryption" ]]

    [#list solution.Links?values as link]
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

            [#if ( 'directory' == (linkTargetCore.Type)!'' ) ]
                [#if linkTargetAttributes.ENGINE == 'ActiveDirectory']
                    [#local directoryId = linkTargetAttributes.DOMAIN_ID]
                [#else]
                    [@fatal message='Invalid directory type. Active Directory required' context=linkTargetAttributes /]
                [/#if]
            [#else]
                [#if deploymentSubsetRequired(EFS_COMPONENT_TYPE, true)]
[#-- Removed to test. Can't see how this ever worked - port not defined
                    [@createSecurityGroupRulesFromLink
                        occurrence=occurrence
                        groupId=efsSecurityGroupId
                        linkTarget=linkTarget
                        inboundPorts=[ port ]
                        networkProfile=networkProfile
                    /]
--]
                [/#if]
            [/#if]

        [/#if]
    [/#list]

    [#if deploymentSubsetRequired(EFS_COMPONENT_TYPE, true) ]

        [@createSecurityGroup
            id=efsSecurityGroupId
            name=efsSecurityGroupName
            vpcId=vpcId
            occurrence=occurrence
        /]

        [@createSecurityGroupRulesFromNetworkProfile
            occurrence=occurrence
            groupId=efsSecurityGroupId
            networkProfile=networkProfile
            inboundPorts=efsSecurityGroupPorts
        /]

        [#local ingressNetworkRule = {
                "Ports" : [ efsSecurityGroupPorts ],
                "IPAddressGroups" : solution.IPAddressGroups
        }]

        [@createSecurityGroupIngressFromNetworkRule
            occurrence=occurrence
            groupId=efsSecurityGroupId
            networkRule=ingressNetworkRule
        /]

        [#-- Create alias list for FSX mounts --]
        [#local aliases = []]
        [#list occurrence.Occurrences![] as subOccurrence]
            [#local subCore = subOccurrence.Core ]
            [#local subSolution = subOccurrence.Configuration.Solution ]
            [#if subCore.Type == EFS_MOUNT_COMPONENT_TYPE ]
                [#local aliases += [ subSolution.Directory ]]
            [/#if]
        [/#list]
        [#local subnets = []]
        [#list getZones() as zone ]
            [#local subnets += getSubnets(core.Tier, networkResources, zone.Id, true, false) ]
        [/#list]
        [#local typeSuffix = (getZones()?size>1)?then("-MULTIAZ","") ]
        [#local fsx_config = {
            "directoryId": directoryId,
            "aliases": aliases,
            "maintenanceWindow": solution["aws:MaintenanceWindow"],
            "subnets": subnets,
            "storageCapacity": solution["aws:StorageCapacity"]
        }]

        [@createEFS
            id=efsId
            tags=getOccurrenceCoreTags(occurrence, efsFullName, "", false)
            encrypted=solution.Encrypted
            kmsKeyId=cmkKeyId
            iamRequired=solution["aws:IAMRequired"]
            type=solution["aws:Type"] + typeSuffix
            fsx_config=fsx_config
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
                type=solution["aws:Type"]
                subnet=getSubnets(core.Tier, networkResources, zone.Id, true, false)
                efsId=efsId
                securityGroups=efsSecurityGroupId
            /]
        [/#list]
    [/#if ]

    [#-- Subcomponents --]
    [#list occurrence.Occurrences![] as subOccurrence]

        [#local subCore = subOccurrence.Core ]
        [#local subSolution = subOccurrence.Configuration.Solution ]
        [#local subResources = subOccurrence.State.Resources ]

        [#if subCore.Type == EFS_MOUNT_COMPONENT_TYPE ]

            [#local efsAccessPointId = subResources["accessPoint"].Id ]
            [#local efsAccessPointName = subResources["accessPoint"].Name ]

            [#if deploymentSubsetRequired(EFS_COMPONENT_TYPE, true) ]
                [@createEFSAccessPoint
                    id=efsAccessPointId
                    efsId=efsId
                    type=solution["aws:Type"]
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
        [/#if]
    [/#list]
[/#macro]
