[#ftl]
[#macro aws_dnszone_cf_deployment_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract
        subsets=["template"]
    /]
[/#macro]

[#macro aws_dnszone_cf_deployment_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]
    [#local attributes = occurrence.State.Attributes ]

    [#local vpcIds = []]

    [#if (solution.Profiles.Network)?has_content]

        [#local networkLink = getOccurrenceNetwork(occurrence).Link!{} ]
        [#local networkLinkTarget = getLinkTarget(occurrence, networkLink ) ]
        [#if ! networkLinkTarget?has_content ]
            [@fatal message="Network could not be found" context=networkLink /]
            [#return]
        [/#if]
        [#local networkConfiguration = networkLinkTarget.Configuration.Solution]
        [#local networkResources = networkLinkTarget.State.Resources ]
        [#local vpcIds = combineEntities(vpcIds, [ networkResources["vpc"].Id ], UNIQUE_COMBINE_BEHAVIOUR)]

    [/#if]

    [@createRoute53HostedZone
        id=resources["zone"].Id
        name=resources["zone"].Name
        tags=getOccurrenceCoreTags(occurrence, occurrence.Core.FullName)
        vpcIds=vpcIds
    /]
[/#macro]
