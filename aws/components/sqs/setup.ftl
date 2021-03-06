[#ftl]
[#macro aws_sqs_cf_deployment_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract
        subsets="template"
        alternatives=[
            "primary",
            { "subset" : "template", "alternative" : "replace1" },
            { "subset" : "template", "alternative" : "replace2" }
        ]
    /]
[/#macro]

[#macro aws_sqs_cf_deployment_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#if deploymentSubsetRequired("sqs", true)]

        [#local core = occurrence.Core ]
        [#local solution = occurrence.Configuration.Solution ]
        [#local resources = occurrence.State.Resources ]

        [#local sqsId = resources["queue"].Id ]
        [#local sqsName = resources["queue"].Name ]

        [#-- override the Id ane Name for replacement --]
        [#if getCLODeploymentUnitAlternative() == "replace1" ]
            [#local sqsId = resources["queue"].ReplaceId ]
            [#local sqsName = resources["queue"].ReplaceName ]
        [/#if]

        [#local dlqRequired = (resources["dlq"]!{})?has_content ]

        [#local queueIds = [ sqsId ]]
        [#local sqsPolicyId = resources["queuePolicy"].Id ]
        [#local queuePolicyStatements = [] ]

        [#local fifoQueue = false]

        [#switch solution.Ordering ]
            [#case "FirstInFirstOut" ]
                [#local fifoQueue = true ]
                [#break]

            [#case "BestEffort" ]
                [#break]

            [#default]
                [@fatal
                    message="SQS Queue Ordering method not supported"
                    context={
                        "Name" : core.Name,
                        "Ordering" : solution.Ordering
                    }
                /]
        [/#switch]

        [#if dlqRequired ]
            [#local dlqId = resources["dlq"].Id ]
            [#local dlqName = resources["dlq"].Name ]

            [#-- override the Id ane Name for replacement --]
            [#if getCLODeploymentUnitAlternative() == "replace1" ]
                [#local dlqId = resources["dlq"].ReplaceId ]
                [#local dlqName = resources["dlq"].ReplaceName ]
            [/#if]


            [#local queueIds += [ dlqId ]]
            [@createSQSQueue
                id=dlqId
                name=dlqName
                retention=1209600
                receiveWait=20
                fifoQueue=fifoQueue
            /]
        [/#if]

        [@createSQSQueue
            id=sqsId
            name=sqsName
            delay=solution.DelaySeconds
            maximumSize=solution.MaximumMessageSize
            retention=solution.MessageRetentionPeriod
            receiveWait=solution.ReceiveMessageWaitTimeSeconds
            visibilityTimeout=solution.VisibilityTimeout
            dlq=valueIfTrue(dlqId!"", dlqRequired, "")
            dlqReceives=
                valueIfTrue(
                solution.DeadLetterQueue.MaxReceives,
                solution.DeadLetterQueue.MaxReceives > 0,
                (environmentObject.Operations.DeadLetterQueue.MaxReceives)!3)
            fifoQueue=fifoQueue
        /]

        [#list solution.Alerts?values as alert ]

            [#local monitoredResources = getCWMonitoredResources(core.Id, resources, alert.Resource)]
            [#list monitoredResources as name,monitoredResource ]

                [#local resourceDimensions = []]
                [#if getCLODeploymentUnitAlternative() == "replace1" ]

                    [#switch monitoredResource.Id ]
                        [#case resources["queue"].Id ]
                            [#local resourceDimensions = [
                                {
                                    "Name": "QueueName",
                                    "Value": resources["queue"].Name
                                }
                            ]]
                            [#break]

                        [#case resources["dlq"].Id ]
                            [#local resourceDimensions = [
                                {
                                    "Name": "QueueName",
                                    "Value": resources["dlq"].Name
                                }
                            ]]
                            [#break]
                    [/#switch]
                [/#if]

                [#if ! resourceDimensions?has_content ]
                    [#local resourceDimensions = getCWMetricDimensions(alert, monitoredResource, resources)]
                [/#if]

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
                            dimensions=resourceDimensions
                        /]
                    [#break]
                [/#switch]
            [/#list]
        [/#list]

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
                            [#local queuePolicyStatements +=
                                    sqsWritePermission(
                                        sqsId,
                                        {"Service" : linkTargetRoles.Inbound["invoke"].Principal},
                                        {
                                            "ArnEquals" : {
                                                "aws:sourceArn" : linkTargetRoles.Inbound["invoke"].SourceArn
                                            }
                                        },
                                        true)  ]
                            [#break]
                    [/#switch]
                    [#break]
            [/#switch]
        [/#list]


        [#if queuePolicyStatements?has_content ]
            [@createSQSPolicy
                id=sqsPolicyId
                queues=queueIds
                statements=queuePolicyStatements
            /]
        [/#if]
    [/#if]
[/#macro]
