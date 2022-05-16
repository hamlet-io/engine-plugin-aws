[#ftl]
[#macro aws_datastream_cf_deployment_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract subsets="template" /]
[/#macro]

[#macro aws_datastream_cf_deployment_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]
    [#local resources = occurrence.State.Resources]

    [#local streamId = resources["stream"].Id ]
    [#local streamName = resources["stream"].Name ]

    [#local encryption = solution.Encryption]

    [#-- Baseline component lookup --]
    [#local baselineLinks           = getBaselineLinks(occurrence, ["Encryption"] )]
    [#local baselineComponentIds    = getBaselineComponentIds(baselineLinks)]
    [#local cmkKeyId                = baselineComponentIds["Encryption"]]

    [#if deploymentSubsetRequired(DATASTREAM_COMPONENT_TYPE, true)]
        [@createKinesisDataStream
            id=streamId
            name=streamName
            streamMode=solution["aws:Capacity"].ProvisiningMode
            retentionHours=( (solution.Lifecycle.Expiration)?is_string && solution.Lifecycle.Expiration == "_operations")?then(
                (operationsExpiration * 24),
                (solution.Lifecycle.Expiration * 24)
            )
            shardCount=(solution["aws:Capacity"].ProvisiningMode == "provsioned")?then(
                solution["aws:Capacity"].Shards,
                ""
            )
            keyId=cmkKeyId
            tags=getOccurrenceCoreTags(occurrence, streamName)
        /]
    [/#if]
[/#macro]
