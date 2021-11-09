[#ftl]
[#macro aws_mta_cf_deployment_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract subsets=["template"]+(occurrence.Configuration.Solution.Direction == "send")?then(["epilogue"],[]) /]
[/#macro]

[#macro aws_mta_cf_deployment_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local attributes = occurrence.State.Attributes ]

    [#switch solution.Direction]
        [#case "send"]
            [#-- Get domain/host information --]
            [#local certificateObject = getCertificateObject(solution.Certificate)]
            [#local certificateDomains = getCertificateDomains(certificateObject) ]

            [#-- Baseline component lookup to obtain the kms key --]
            [#local baselineLinks = getBaselineLinks(occurrence, [ "Encryption" ] )]
            [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
            [#local kmsKeyId = baselineComponentIds["Encryption"]!""]

            [#local configSetName = formatName(occurrence.Core.FullName) ]

            [#if deploymentSubsetRequired(MTA_COMPONENT_TYPE, true) ]
                [#local csTags = getOccurrenceCoreTags(occurrence, configSetName)]

                [#-- CF doesn't support tags but the console does, so included for future expansion --]
                [@createSESConfigSet
                    id=formatSESConfigSetId()
                    name=configSetName
                    tags=csTags
                /]
            [/#if]

            [#-- Process the rules according to the provided order --]
            [#list (occurrence.Occurrences![]) as subOccurrence]
                [#local core = subOccurrence.Core ]
                [#local solution = subOccurrence.Configuration.Solution ]
                [#local resources = subOccurrence.State.Resources ]

                [#local configId = resources["configSet"].Id ]
                [#local configName = resources["configSet"].Name ]

                [#local eventTypes = solution.Conditions.EventTypes ]
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
                                    [#if deploymentSubsetRequired(MTA_COMPONENT_TYPE, true) ]
                                        [@createSNSPolicy
                                            id=formatResourceId(AWS_SNS_TOPIC_POLICY_RESOURCE_TYPE, configId, link.Id)
                                            topics=topicArn
                                            statements=getSnsStatement(
                                                "sns:Publish",
                                                topicArn
                                                {
                                                    "Service" : "ses.amazonaws.com"
                                                },
                                                {
                                                    "StringEquals" : {
                                                        "AWS:SourceAccount" : { "Ref" : "AWS::AccountId" }
                                                    }
                                                }
                                            )
                                        /]
                                    [/#if]
                                    [#break]
                                [/#if]
                            [/#if]
                        [/#list]
                    [#break]

                    [#case "drop"]
                    [#break]
                [/#switch]

                [#if eventTypes?has_content]
                    [#if topicArn?has_content]
                        [#-- notifications must be done through CLI --]
                        [#if deploymentSubsetRequired("epilogue", false) ]
                            [#local configJSON = {
                                    "Name": configName,
                                    "Enabled": solution.Enabled,
                                    "MatchingEventTypes": asArray(eventTypes)
                                }+
                                (topicArn?has_content)?then(
                                    {
                                        "SNSDestination": {
                                            "TopicARN": topicArn
                                        }
                                    },
                                    {}
                                )
                            ]
                            [#-- CloudFormation cannot update a stack when a custom-named resource requires replacing and
                                 configsets are custom-named, hence when tags are added, care is needed. Currently only
                                 attribute is name which can not change --]
                            [@addToDefaultBashScriptOutput
                                content=
                                [
                                    r'case ${STACK_OPERATION} in',
                                    r'  create)',
                                    r'    info "Assign destination"',
                                    r'    aws --region "' + getRegion() + r'" ses create-configuration-set-event-destination --configuration-set-name ' + configSetName + ' --event-destination  \'${getJSON(configJSON)}\''
                                    r'    ;;'
                                    r'  update)',
                                    r'    info "Update configsets"',
                                    r'    aws --region "' + getRegion() + r'" ses update-configuration-set-event-destination --configuration-set-name ' + configSetName + ' --event-destination  \'${getJSON(configJSON)}\''
                                    r'    ;;'
                                ]+
                                [
                                    "esac"
                                ]
                            /]

                            [#if getExistingReference(formatResourceId(AWS_SNS_TOPIC_POLICY_RESOURCE_TYPE, ruleId, link.Id))?has_content ]
                                [@warn
                                    message="Topic Permissions update required"
                                    detail=[
                                        "SNS policies have been migrated to the topic component",
                                        "For each S3 bucket add an inbound-invoke link from the Topic to the bucket",
                                        "When this is completed update the configuration of this notification to TopicPermissionMigration : true"
                                    ]?join(',')
                                    context=subOccurrence.Core.RawId
                                /]
                            [/#if]
                            [#break]
                        [/#if]
                    [/#if]
                [/#if]
            [/#list]
        [#break]

        [#case "receive"]
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

                                    [@createSNSPolicy
                                        id=formatResourceId(AWS_SNS_TOPIC_POLICY_RESOURCE_TYPE, ruleId, link.Id)
                                        topics=topicArn
                                        statements=getSnsStatement(
                                            "sns:Publish",
                                            topicArn
                                            {
                                                "Service" : "ses.amazonaws.com"
                                            },
                                            {
                                                "StringEquals" : {
                                                    "AWS:SourceAccount" : { "Ref" : "AWS::AccountId" }
                                                }
                                            }
                                        )
                                    /]
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
        [#break]
    [/#switch]
[/#macro]
