[#ftl]
[#macro aws_mta_cf_deployment_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract subsets=["template"]+(occurrence.Configuration.Solution.Direction == "send")?then(["epilogue"],[]) /]
[/#macro]

[#macro aws_mta_cf_deployment_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local attributes = occurrence.State.Attributes ]
    [#local resources = occurrence.State.Resources]

    [#-- Get domain/host information --]
    [#local certificateObject = getCertificateObject(solution.Hostname)]
    [#local mailDomains = getCertificateDomains(certificateObject) ]

    [#-- Baseline component lookup to obtain the kms key --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "Encryption" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local kmsKeyId = baselineComponentIds["Encryption"]!""]

    [#local direction = solution.Direction]

    [#switch direction]
        [#case "send"]

            [#-- Process the rules according to the provided order --]
            [#list (occurrence.Occurrences![]) as subOccurrence]
                [#local core = subOccurrence.Core ]
                [#local solution = subOccurrence.Configuration.Solution ]
                [#local resources = subOccurrence.State.Resources ]

                [#local eventTypes = solution.EventTypes ]

                [#local emailSendIdentities = expandSESRecipients(solution.Conditions.Senders, mailDomains)]

                [#local configSet = resources["configset"]]

                [#if deploymentSubsetRequired(MTA_COMPONENT_TYPE, true) ]
                    [@createSESConfigSet
                        id=configSet.Id
                        name=configSet.Name
                    /]
                [/#if]

                [#list expandSESRecipients(solution.Conditions.Senders, mailDomains) as emailAddr]
                    [#if deploymentSubsetRequired("epilogue", false) ]
                        [@addToDefaultBashScriptOutput
                            content=
                            [
                                r'case ${STACK_OPERATION} in',
                                r'  create|update)',
                                r'    if [ -z "$(aws --region "' + getRegion() + r'" ses list-identities --query ' + r"'Identities[?@==`" + emailAddr + r"`]'" + r' --output text)" ]; then',
                                r'       info "Creating email identity and assigning config set for identity: ' + emailAddr + r'"',
                                r'       aws --region "' + getRegion() + r'" sesv2 create-email-identity --email-identity ' + emailAddr + r' --configuration-set-name ' + configSet.Name,
                                r'    else',
                                r'       info "Updating email identity and configset for identity: ' + emailAddr + r'"',
                                r'       aws --region "' + getRegion() + r'" sesv2 put-email-identity-configuration-set-attributes --email-identity ' + emailAddr + r' --configuration-set-name ' + configSet.Name,
                                r'    fi'
                                r'    ;;'
                                r'  delete)'
                                r'    if [ -z "$(aws --region "' + getRegion() + r'" ses list-identities --query ' + r"'Identities[?@==`" + emailAddr + r"`]'" + r' --output text)" ]; then',
                                r'       info "Removing configset from email identity: ' + emailAddr + r'"',
                                r'       aws --region "' + getRegion() + r'" sesv2 put-email-identity-configuration-set-attributes --email-identity ' + emailAddr,
                                r'    fi',
                                r'    ;;',
                                r'esac'
                            ]
                        /]
                    [/#if]
                [/#list]


                [#switch solution.Action]
                    [#case "log"]
                        [#local encryptionEnabled = isPresent(solution["aws:Encryption"]) ]

                        [#-- Look for any link to a topic --]
                        [#list solution.Links as linkId, link]
                            [#if link?is_hash]

                                [#local linkTarget = getLinkTarget(occurrence, link) ]
                                [@debug message="Link Target" context=linkTarget enabled=false /]

                                [#if !linkTarget?has_content]
                                    [#continue]
                                [/#if]

                                [#switch linkTarget.Core.Type ]
                                    [#case TOPIC_COMPONENT_TYPE]

                                        [#if getExistingReference(formatResourceId(AWS_SNS_TOPIC_POLICY_RESOURCE_TYPE, ruleId, link.Id))?has_content ]
                                            [@warn
                                                message="Topic Permissions update required"
                                                detail=[
                                                    "SNS policies have been migrated to the topic component",
                                                    "For each MTA add an inbound-invoke link from the Topic to the mta",
                                                    "When this is completed update the configuration of this notification to TopicPermissionMigration : true"
                                                ]?join(',')
                                                context=subOccurrence.Core.RawId
                                            /]
                                        [/#if]

                                        [#if deploymentSubsetRequired("epilogue", false) ]
                                            [#local configJSON = {
                                                    "Name": linkId,
                                                    "Enabled": true,
                                                    "MatchingEventTypes": asArray(eventTypes),
                                                    "SNSDestination": {
                                                        "TopicARN": linkTarget.State.Attributes.ARN
                                                    }
                                                }]

                                            [@addToDefaultBashScriptOutput
                                                content=
                                                [
                                                    r'case ${STACK_OPERATION} in',
                                                    r'  create|update)',
                                                    r'    info "Adding event destination for rule link: ' + linkId + r'"',
                                                    r'    # ensure that the config set is available',
                                                    r'    config_set_name="$(get_cloudformation_stack_output "' + getRegion() + r'" "${STACK_NAME}" "' + configSet.Id + r'" "name" || return $?)"',
                                                    r'    if [[ "$(aws --region "' +  getRegion() + r'" ses describe-configuration-set --configuration-set-name "$config_set_name" --configuration-set-attribute-names eventDestinations --query ' + r"'EventDestinations[?Name==`" + linkId + r"`].Name'" + r')" == "null" ]]; then',
                                                    r'      aws --region "' + getRegion() + r'" ses create-configuration-set-event-destination --configuration-set-name "${config_set_name}" --event-destination ' + '\'${getJSON(configJSON)}\'',
                                                    r'    else',
                                                    r'      aws --region "' + getRegion() + r'" ses update-configuration-set-event-destination --configuration-set-name "${config_set_name}" --event-destination ' + '\'${getJSON(configJSON)}\'',
                                                    r'    fi',
                                                    r'    ;;'
                                                    r'esac'
                                                ]
                                            /]

                                            [#break]
                                        [/#if]

                                    [#break]

                                [/#switch]
                            [/#if]
                        [/#list]
                    [#break]

                    [#default]
                        [@fatal
                            message="Action not supported for the mta direction"
                            context={
                                "Id" : occurrence.Core.RawId,
                                "Direction" : direction,
                                "Action" : solution.Action
                            }
                        /]
                    [#break]
                [/#switch]

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

            [#local lastRuleName = getOccurrenceSettingValue(occurrence, ["AFTER","RULE","NAME"], true)]

            [#-- Process the rules according to the provided order --]
            [#list (occurrence.Occurrences![])?sort_by(['Configuration', 'Solution', 'Order']) as subOccurrence]

                [#local core = subOccurrence.Core ]
                [#local solution = subOccurrence.Configuration.Solution ]
                [#local resources = subOccurrence.State.Resources ]

                [#local ruleId = resources["rule"].Id ]
                [#local ruleName = resources["rule"].Name ]

                [#local actions = [] ]
                [#local topicArns = [] ]

                [#-- Look for any link to a topic --]
                [#list solution.Links?values as link]
                    [#if link?is_hash]

                        [#local linkTarget = getLinkTarget(occurrence, link) ]
                        [@debug message="Link Target" context=linkTarget enabled=false /]

                        [#if !linkTarget?has_content]
                            [#continue]
                        [/#if]

                        [#if linkTarget.Core.Type == TOPIC_COMPONENT_TYPE ]
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

                            [#local topicArns = combineEntities(topicArns, (linkTarget.State.Attributes["ARN"])!"", UNIQUE_COMBINE_BEHAVIOUR)]
                            [#break]
                        [/#if]
                    [/#if]
                [/#list]

                [#switch solution.Action]
                    [#case "forward"]
                        [#local encryptionEnabled = isPresent(solution["aws:Encryption"]) ]

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
                                                (topicArns[0])!""
                                            )
                                        ]
                                        [#break]

                                    [#case LAMBDA_FUNCTION_COMPONENT_TYPE ]
                                        [#local actions +=
                                            getSESReceiptLambdaAction(
                                                linkTargetAttributes["ARN"]!"",
                                                true,
                                                (topicArns[0])!""
                                            )
                                        ]
                                        [#break]
                                [/#switch]
                            [/#if]
                        [/#list]
                        [#break]

                    [#case "drop"]
                        [#list topicArns as topicArn]
                            [#local actions += getSESReceiptStopAction("RuleSet", topicArn) ]
                        [/#list]
                        [#break]
                [/#switch]

                [#if actions?has_content]
                    [@createSESReceiptRule
                        id=ruleId
                        name=ruleName
                        ruleSetName=ruleSetName
                        actions=actions
                        afterRuleName=lastRuleName
                        recipients=expandSESRecipients(solution.Conditions.Recipients, mailDomains)
                        enabled=solution.Enabled
                    /]
                    [#local lastRuleName = getReference(ruleId)]
                [/#if]
            [/#list]
        [#break]
    [/#switch]
[/#macro]
