[#ftl]
[#macro aws_mta_cf_deployment_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract subsets=["template"] /]
[/#macro]

[#macro aws_mta_cf_deployment_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]

    [#if solution.Direction != "receive"]
        [#-- Only support for receipt rules right now --]
        [#return]
    [/#if]

    [#-- Get domain/host information --]
    [#local certificateObject = getCertificateObject(solution.Certificate, segmentQualifiers)]
    [#local certificateDomains = getCertificateDomains(certificateObject) ]

    [#-- Baseline component lookup to obtain the kms key --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "Encryption" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local kmsKeyId = baselineComponentIds["Encryption"]!""]

    [#local ruleSetId = resources["ruleset"].Id ]
    [#local ruleSetName = resources["ruleset"].Name ]

    [#-- First add any required IP Address filtering --]
    [#if getGroupCIDRs(solution.IPAddressGroups, true, occurrence, true)]
        [#list (getGroupCIDRs(solution.IPAddressGroups, true, occurrence))?filter(cidr -> cidr?has_content) as cidr ]
            [@createSESReceiptIPFilter
                id=formatResourceId(AWS_SES_RECEIPT_FILTER_RESOURCE_TYPE, core.Id, replaceAlphaNumericOnly(cidr,"X"))
                name=formatComponentFullName(core.Tier, core.Component, occurrence,replaceAlphaNumericOnly(cidr,"-"))
                cidr=cidr
            /]
        [/#list]

        [#-- Add a default block all rule --]
        [@createSESReceiptIPFilter
                id=formatResourceId(AWS_SES_RECEIPT_FILTER_RESOURCE_TYPE, core.Id, "0X0X0X0X0")
                name=formatComponentFullName(core.Tier, core.Component, occurrence, "0-0-0-0-0")
                cidr="0.0.0.0/0"
                allow=false
            /]
    [/#if]

    [#if deploymentSubsetRequired(MTA_COMPONENT_TYPE, true) ]
        [#-- Create a ruleset --]
        [@createSESReceiptRuleSet
            id=ruleSetId
            name=ruleSetName
        /]
    [/#if]

    [#local lastRuleName = ""]

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

        [#if actions?has_content && deploymentSubsetRequired(MTA_COMPONENT_TYPE, true)]
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
