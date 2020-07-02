[#ftl]
[#macro aws_efs_cf_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract subsets="template" /]
[/#macro]

[#macro aws_efs_cf_setup_solution occurrence ]
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

    [#local networkProfile = getNetworkProfile(solution.Profiles.Network)]

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

            [#if deploymentSubsetRequired(EFS_COMPONENT_TYPE, true)]
                [@createSecurityGroupRulesFromLink
                    occurrence=occurrence
                    groupId=efsSecurityGroupId
                    linkTarget=linkTarget
                    inboundPorts=[ port ]
                    networkProfile=networkProfile
                /]
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

        [@createEFS
            tier=core.Tier
            id=efsId
            name=efsFullName
            component=core.Component
            encrypted=solution.Encrypted
            kmsKeyId=cmkKeyId
        /]

        [#list zones as zone ]
            [#local zoneEfsMountTargetId   = zoneResources[zone.Id]["efsMountTarget"].Id]
            [@createEFSMountTarget
                id=zoneEfsMountTargetId
                subnet=getSubnets(core.Tier, networkResources, zone.Id, true, false)
                efsId=efsId
                securityGroups=efsSecurityGroupId
            /]
        [/#list]
    [/#if ]
[/#macro]
