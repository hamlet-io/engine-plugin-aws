[#ftl]

[#macro aws_logstore_cf_deployment_generationcontract occurrence ]
    [@addDefaultGenerationContract subsets=[ "template" ] /]
[/#macro]

[#macro aws_logstore_cf_deployment occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]

    [#local lg = resources["lg"]]

    [#local loggingProfile = getLoggingProfile(occurrence)]

    [#-- Baseline lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "Encryption"] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]

    [#local cmkKeyId = baselineComponentIds["Encryption" ]]

    [#switch solution.Engine ]
        [#case "aws:cloudwatchlogs"]
            [@setupLogGroup
                occurrence=occurrence
                logGroupId=lg.Id
                logGroupName=lg.Name
                loggingProfile=loggingProfile
                kmsKeyId=cmkKeyId
                retention=( (solution.Lifecycle.Expiration)?is_string && solution.Lifecycle.Expiration == "_operations")?then(
                    operationsExpiration,
                    solution.Lifecycle.Expiration
                )
            /]
            [#break]

        [#default]
            [@fatal
                message="Unsupported engine for aws logstore"
                context={
                    "Name" : occurrence.Core.FullRawName,
                    "Engine": solution.Engine
                }

            /]
    [/#switch]
[/#macro]
