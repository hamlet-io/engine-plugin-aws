[#ftl]

[#macro aws_correspondent_cf_deployment_generationcontract occurrence ]
    [@addDefaultGenerationContract subsets=["template"] /]
[/#macro]

[#macro aws_correspondent_cf_deployment occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]

    [#local correspondentId = resources["correspondent"].Id ]
    [#local correspondentName = resources["correspondent"].Name ]

    [@createPinpointApp
        id=correspondentId
        name=correspondentName
        tags=getOccurrenceTags(occurrence)
    /]
[/#macro]
