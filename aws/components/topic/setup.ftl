[#ftl]
[#macro aws_topic_cf_deployment_generationcontract occurrence ]
    [@addDefaultGenerationContract subsets="template" /]
[/#macro]

[#macro aws_topic_cf_deployment occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]
    [#local resources = occurrence.State.Resources]

    [#local topicId = resources["topic"].Id ]
    [#local topicName = resources["topic"].Name ]

    [#local topicPolicyId = resources["policy"].Id ]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "Encryption" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local cmkKeyId = baselineComponentIds["Encryption"] ]

    [#if deploymentSubsetRequired(TOPIC_COMPONENT_TYPE, true) ]

        [@createSNSTopic
            id=topicId
            name=topicName
            encrypted=solution.Encrypted
            kmsKeyId=cmkKeyId
            fixedName=solution.FixedName
            tags=getOccurrenceCoreTags(
                    occurrence,
                    topicName)
        /]

        [#--  Alerts --]
        [#list solution.Alerts?values as alert ]

            [#local monitoredResources = getCWMonitoredResources(core.Id, resources, alert.Resource)]
            [#list monitoredResources as name,monitoredResource ]

                [@debug message="Monitored resource" context=monitoredResource enabled=false /]

                [#switch alert.Comparison ]
                    [#case "Threshold" ]
                        [@createAlarm
                            id=formatDependentAlarmId(monitoredResource.Id, alert.Id )
                            severity=alert.Severity
                            resourceName=core.FullName
                            alertName=alert.Name
                            actions=getCWAlertActions(occurrence, solution.Profiles.Alert, alert.Severity )
                            metric=getCWMetricName(alert.Metric, monitoredResource.Type, core.ShortFullName)
                            namespace=getCWResourceMetricNamespace(monitoredResource.Type, alert.Namespace)
                            description=alert.Description!alert.Name
                            threshold=alert.Threshold
                            statistic=alert.Statistic
                            evaluationPeriods=alert.Periods
                            period=alert.Time
                            operator=alert.Operator
                            reportOK=alert.ReportOk
                            unit=alert.Unit
                            missingData=alert.MissingData
                            dimensions=getCWMetricDimensions(alert, monitoredResource, resources)
                        /]
                    [#break]
                [/#switch]
            [/#list]
        [/#list]

        [#local topicPolicyStatements = []]

        [#list solution.Links as linkId,link]

            [#local linkTarget = getLinkTarget(occurrence, link) ]

            [@debug message="Link Target" context=linkTarget enabled=false /]

            [#if !linkTarget?has_content]
                [#continue]
            [/#if]

            [#local linkTargetCore = linkTarget.Core ]
            [#local linkTargetResources = linkTarget.State.Resources ]
            [#local linkTargetRoles = linkTarget.State.Roles ]
            [#local linkDirection = linkTarget.Direction ]
            [#local linkRole = linkTarget.Role]

            [#switch linkDirection ]
                [#case "inbound" ]
                    [#switch linkRole ]
                        [#case "invoke" ]

                            [#local sourceCondition = {}]

                            [#switch linkTargetCore.Type ]
                                [#case MTA_COMPONENT_TYPE ]
                                    [#local sourceCondition = {
                                        "StringEquals" : {
                                            "AWS:SourceAccount" : linkTargetRoles.Inbound["invoke"].SourceAccount
                                        }
                                    }]
                                    [#break]

                                [#default]
                                    [#local sourceCondition = {
                                        "ArnLike" : {
                                            "aws:sourceArn" : linkTargetRoles.Inbound["invoke"].SourceArn
                                        }
                                    }]
                            [/#switch]

                            [#local topicPolicyStatements +=
                                        [ snsPublishPermission(
                                            topicId,
                                            { "Service" : linkTargetRoles.Inbound["invoke"].Principal },
                                            sourceCondition,
                                            true,
                                            linkId
                                        )] ]
                            [#break]
                    [/#switch]
                    [#break]
            [/#switch]
        [/#list]

        [#if topicPolicyStatements?has_content ]
            [@createSNSPolicy
                id=topicPolicyId
                topics=topicId
                statements=topicPolicyStatements
            /]
        [/#if]
    [/#if]

    [#list occurrence.Occurrences![] as subOccurrence]

        [#local core = subOccurrence.Core ]
        [#local solution = subOccurrence.Configuration.Solution ]
        [#local resources = subOccurrence.State.Resources ]

        [#local subscriptionDependencies = []]

        [#switch core.Type]

            [#case TOPIC_SUBSCRIPTION_COMPONENT_TYPE  ]
                [#local filterPolicy = {}]
                [#local subscriptionId = resources["subscription"].Id ]
                [#list (solution["Filters"]!{}) as FilterKey, FilterVal]
                    [#if (FilterVal.Links!"")?has_content]
                        [#local bucketList = []]
                        [#list FilterVal.Links as LinkKey, LinkVal]
                            [#local foundLink = getLinkTarget(subOccurrence, LinkVal, false) ]
                            [#switch FilterVal.Attribute?lower_case]
                                [#case "bucket"]
                                [#case "bucketname"]
                                    [#local bucketList += [ foundLink.State.Resources.bucket.Name ]]
                                [#break]
                            [/#switch]
                        [/#list]
                        [#local filterPolicy += { FilterVal.Attribute : bucketList }]
                    [#else]
                        [#local filterPolicy += { FilterVal.Attribute : FilterVal.Values }]
                    [/#if]
                [/#list]
                [#local links = solution.Links ]

                [#list links as linkId,link]

                    [#local linkTarget = getLinkTarget(occurrence, link) ]

                    [@debug message="Link Target" context=linkTarget enabled=false /]

                    [#if !linkTarget?has_content]
                        [#continue]
                    [/#if]

                    [#local linkTargetCore = linkTarget.Core ]
                    [#local linkTargetConfiguration = linkTarget.Configuration ]
                    [#local linkTargetResources = linkTarget.State.Resources ]
                    [#local linkTargetAttributes = linkTarget.State.Attributes ]

                    [#local endpoint = ""]
                    [#local protocol = ""]
                    [#local deliveryPolicy = {}]

                    [#switch linkTargetCore.Type ]
                        [#case "external" ]
                        [#case EXTERNALSERVICE_COMPONENT_TYPE ]
                            [#local endpoint = linkTargetAttributes["SUBSCRIPTION_ENDPOINT"]!"" ]
                            [#local protocol = linkTargetAttributes["SUBSCRIPTION_PROTOCOL"]!"" ]

                            [#if ! endpoint?has_content && ! protocol?has_content ]
                                [@fatal
                                    message="Subscription protocol or endpoints not found"
                                    context=link
                                    detail="External link Attributes Required SUBSCRIPTION_ENDPOINT - SUBSCRIPTION_PROTOCOL"
                                /]
                            [/#if]
                            [#break]

                        [#case LAMBDA_FUNCTION_COMPONENT_TYPE ]
                            [#local endpoint = linkTargetAttributes["ARN"] ]
                            [#local protocol = "lambda"]
                            [#break]

                        [#case SQS_COMPONENT_TYPE]
                            [#local endpoint = linkTargetAttributes["ARN"] ]
                            [#local protocol = "sqs" ]
                            [#break]
                    [/#switch]

                    [#if ! endpoint?has_content && ! protocol?has_content ]
                        [@fatal
                            message="Subscription protocol or endpoints not found"
                            context=link
                            detail="Could not determine protocol and endpoint for link"
                        /]
                    [/#if]


                    [#switch protocol ]
                        [#case "http"]
                        [#case "https" ]
                            [#local deliveryPolicy = getSNSDeliveryPolicy(solution.DeliveryPolicy) ]
                            [#break]
                    [/#switch]

                    [#if deploymentSubsetRequired(TOPIC_COMPONENT_TYPE, true)]
                        [@createSNSSubscription
                            id=formatId(subscriptionId, link.Id)
                            topicId=topicId
                            endpoint=endpoint
                            protocol=protocol
                            rawMessageDelivery=solution.RawMessageDelivery
                            deliveryPolicy=deliveryPolicy
                            filterPolicy=filterPolicy
                            dependencies=subscriptionDependencies
                        /]
                    [/#if]
                [/#list]
                [#break]
        [/#switch]
    [/#list]
[/#macro]
