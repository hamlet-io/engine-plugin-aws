[#ftl]
[#macro aws_mta_cf_deployment_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract subsets=["template"] /]
[/#macro]

[#macro aws_mta_cf_deployment_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#-- Nothing to do if not running the template pass --]
    [#if ! deploymentSubsetRequired(MTA_COMPONENT_TYPE, true) ]
        [#return]
    [/#if]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local attributes = occurrence.State.Attributes ]

    [#if solution.Direction != "receive"]
        [#-- Only support for receipt rules right now --]
        [#return]
    [/#if]

    [#local ruleSetName = attributes["RULESET"] ]
    [#if ! ruleSetName?has_content ]
        [@fatal
            message="SES account level configuration has not been completed in the current region. Run the account level sesruleset unit."
        /]
        [#return]
    [/#if]

    [#-- Get domain/host information --]
    [#local certificateObject = getCertificateObject(solution.Certificate)]
    [#local certificateDomains = getCertificateDomains(certificateObject) ]

    [#-- Baseline component lookup to obtain the kms key --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "Encryption" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local kmsKeyId = baselineComponentIds["Encryption"]!""]

    [#local lastRuleName = getOccurrenceSettingValue(occurrence, ["AFTER","RULE","NAME"], true)]

    [#-- Process the rules according to the provided order --]
    [#list (occurrence.Occurrences![])?sort_by(['Configuration', 'Solution', 'Order']) as subOccurrence]

        [#local core = subOccurrence.Core ]
        [#local solution = subOccurrence.Configuration.Solution ]
        [#local resources = subOccurrence.State.Resources ]

        [#local ruleId = resources["rule"].Id ]
        [#local ruleName = resources["rule"].Name ]

        [#local actions = [] ]
        [#local topicArn = "" ]
        [#switch solution.Action]
            [#case "forward"]
                [#local encryptionEnabled = isPresent(solution["aws:Encryption"]) ]

                [#-- Look for any link to a topic --]
                [#list solution.Links?values as link]
                    [#if link?is_hash]

                        [#local linkTarget = getLinkTarget(occurrence, link) ]
                        [@debug message="Link Target" context=linkTarget enabled=false /]

                        [#if !linkTarget?has_content]
                            [#continue]
                        [/#if]

                        [#if linkTarget.Core.Type == TOPIC_COMPONENT_TYPE ]
                            [#local topicArn = linkTarget.State.Attributes["ARN"] ]
                            [#break]
                        [/#if]
                    [/#if]
                [/#list]
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

                        [#switch linkTargetCore.Type]
                            [#case EXTERNALSERVICE_COMPONENT_TYPE ]
                            [#case S3_COMPONENT_TYPE ]
                                [#local actions +=
                                    getSESReceiptS3Action(
                                        linkTargetAttributes["NAME"]!"",
                                        solution["aws:Prefix"]!"",
                                        valueIfTrue(kmsKeyId,encryptionEnabled,""),
                                        topicArn
                                    )
                                ]
                                [#break]

                            [#case LAMBDA_FUNCTION_COMPONENT_TYPE ]
                                [#local actions +=
                                    getSESReceiptLambdaAction(
                                        linkTargetAttributes["ARN"]!"",
                                        true,
                                        topicArn
                                    )
                                ]
                                [#break]
                        [/#switch]
                    [/#if]
                [/#list]
                [#break]

            [#case "drop"]
                [#local actions += getSESReceiptStopAction("RuleSet", topicArn) ]
                [#break]
        [/#switch]

        [#if actions?has_content]
            [@createSESReceiptRule
                id=ruleId
                name=ruleName
                ruleSetName=ruleSetName
                actions=actions
                afterRuleName=lastRuleName
                recipients=expandSESRecipients(solution.Conditions.Recipients, certificateDomains)
                enabled=solution.Enabled
            /]
            [#local lastRuleName = ruleName]
        [/#if]
    [/#list]
[/#macro]
