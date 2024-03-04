[#ftl]
[#macro aws_mobilenotifier_cf_deployment_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract subsets=["deploymentcontract", "prologue", "template", "epilogue", "cli"] /]
[/#macro]

[#macro aws_mobilenotifier_cf_deployment_deploymentcontract occurrence ]
    [@addDefaultAWSDeploymentContract prologue=true epilogue=true /]
[/#macro]

[#macro aws_mobilenotifier_cf_deployment_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]
    [#local resources = occurrence.State.Resources]

    [#local successSampleRate = solution.SuccessSampleRate ]
    [#local encryptionScheme = solution.Credentials.EncryptionScheme?ensure_ends_with(":")]

    [#local deployedPlatformAppArns = []]

    [#local roleId = resources["role"].Id]

    [#local platformAppAttributesCommand = "attributesPlatformApp" ]
    [#local platformAppDeleteCommand = "deletePlatformApp" ]

    [#local hasPlatformApp = false]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "OpsData", "AppData", "Encryption", "SSHKey" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local kmsKeyId = baselineComponentIds["Encryption"] ]

    [#list (occurrence.Occurrences![])?filter(x -> x.Configuration.Solution.Enabled ) as subOccurrence]

        [#local core = subOccurrence.Core ]
        [#local solution = subOccurrence.Configuration.Solution ]
        [#local resources = subOccurrence.State.Resources ]

        [#local successSampleRate = solution.SuccessSampleRate!successSampleRate ]
        [#local encryptionScheme = solution.EncryptionScheme!encryptionScheme]

        [#local loggingProfile = getLoggingProfile(occurrence)]

        [#local platformAppId = resources["platformapplication"].Id]
        [#local platformAppName = resources["platformapplication"].Name ]
        [#local engine = resources["platformapplication"].Engine ]

        [#local lgId= resources["lg"].Id ]
        [#local lgName = resources["lg"].Name ]
        [#local lgFailureId = resources["lgfailure"].Id ]
        [#local lgFailureName = resources["lgfailure"].Name ]

        [#local platformAppAttributesCliId = formatId( platformAppId, "attributes" )]

        [#local platformArn = getExistingReference( platformAppId, ARN_ATTRIBUTE_TYPE) ]

        [#if platformArn?has_content ]
            [#local deployedPlatformAppArns += [ platformArn ] ]
        [/#if]

        [#local isPlatformApp = false]

        [#local platformAppCreateCli = {} ]
        [#local platformAppUpdateCli = {} ]

        [#local platformAppPrincipal =
            getOccurrenceSettingValue(occurrence, ["MobileNotifier", core.SubComponent.Name + "_Principal"], true) ]

        [#local platformAppCredential =
            getOccurrenceSettingValue(occurrence, ["MobileNotifier", core.SubComponent.Name + "_Credential"], true) ]

        [#local engineFamily = "" ]

        [#switch engine ]
            [#case "APNS" ]
            [#case "APNS_SANDBOX" ]
                [#local engineFamily = "APPLE" ]
                [#break]

            [#case "GCM" ]
                [#local engineFamily = "GOOGLE" ]
                [#break]

            [#case MOBILENOTIFIER_SMS_ENGINE ]
                [#local engineFamily = MOBILENOTIFIER_SMS_ENGINE ]
                [#break]

            [#default]
                [@fatal
                    message="Unknown Engine"
                    context=component
                    detail=engine /]
        [/#switch]

        [#switch engineFamily ]
            [#case "APPLE" ]
                [#local isPlatformApp = true]
                [#local hasPlatformApp = true]
                [#if !platformAppCredential?has_content || !platformAppPrincipal?has_content ]
                    [@fatal
                        message="Missing Credentials - Requires both Credential and Principal"
                        context=component
                        detail={
                            "Credential" : platformAppCredential!"",
                            "Principal" : platformAppPrincipal!""
                        } /]
                [/#if]
                [#break]

            [#case "GOOGLE" ]
                [#local isPlatformApp = true]
                [#local hasPlatformApp = true]
                [#if !platformAppPrincipal?has_content ]
                    [@fatal
                        message="Missing Credential - Requires Principal"
                        context=component
                        detail={
                            "Principal" : platformAppPrincipal!""
                        } /]
                [/#if]
                [#break]
        [/#switch]

        [#if deploymentSubsetRequired("lg", true) &&
            isPartOfCurrentDeploymentUnit(lgId)]

            [#if engine != MOBILENOTIFIER_SMS_ENGINE]
                [@setupLogGroup
                    occurrence=subOccurrence
                    logGroupId=lgId
                    logGroupName=lgName
                    loggingProfile=loggingProfile
                    kmsKeyId=kmsKeyId
                /]

                [@setupLogGroup
                    occurrence=subOccurrence
                    logGroupId=lgFailureId
                    logGroupName=lgFailureName
                    loggingProfile=loggingProfile
                    kmsKeyId=kmsKeyId
                /]
            [/#if]

        [/#if]

        [#if deploymentSubsetRequired(MOBILENOTIFIER_COMPONENT_TYPE, true)]

            [#list resources.logMetrics!{} as logMetricName,logMetric ]

                [@createLogMetric
                    id=logMetric.Id
                    name=logMetric.Name
                    logGroup=logMetric.LogGroupName
                    filter=getReferenceData(LOGFILTER_REFERENCE_TYPE)[logMetric.LogFilter].Pattern
                    namespace=getCWResourceMetricNamespace(logMetric.Type)
                    value=1
                    dependencies=logMetric.LogGroupId
                /]

            [/#list]

            [#list (solution.Alerts?values)?filter(x -> x.Enabled) as alert ]

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
                                actions=getCWAlertActions(subOccurrence, solution.Profiles.Alert, alert.Severity )
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
        [/#if]

        [#if isPlatformApp ]
            [#if deploymentSubsetRequired("cli", false ) ]

                [#local platformAppAttributes =
                    getSNSPlatformAppAttributes(
                        roleId,
                        successSampleRate
                        platformAppCredential,
                        platformAppPrincipal )]

                [@addCliToDefaultJsonOutput
                    id=platformAppAttributesCliId
                    command=platformAppAttributesCommand
                    content=platformAppAttributes
                /]

            [/#if]

            [#if deploymentSubsetRequired( "epilogue", false) ]

                [@addToDefaultBashScriptOutput
                    content=
                        [
                            "# Platform: " + core.SubComponent.Name,
                            "case $\{STACK_OPERATION} in",
                            "  create|update)",
                            "       # Get cli config file",
                            "       split_cli_file \"$\{CLI}\" \"$\{tmpdir}\" || return $?",
                            "       info \"Deploying SNS PlatformApp: " + core.SubComponent.Name + "\"",
                            "       platform_app_arn=\"$(deploy_sns_platformapp" +
                            "       \"" + getRegion() + "\" " +
                            "       \"" + platformAppName + "\" " +
                            "       \"" + platformArn + "\" " +
                            "       \"" + encryptionScheme + "\" " +
                            "       \"" + engine + "\" " +
                            "       \"$\{tmpdir}/cli-" +
                                    platformAppAttributesCliId + "-" + platformAppAttributesCommand + ".json\")\""
                        ] +
                        pseudoStackOutputScript(
                            "SNS Platform App",
                            {
                                platformAppId : core.Name,
                                formatId(platformAppId, ARN_ATTRIBUTE_TYPE) : "$\{platform_app_arn}",
                                formatId(platformAppId, REGION_ATTRIBUTE_TYPE) : getRegion()
                            },
                            core.SubComponent.Id
                        ) +
                        [
                            "       ;;",
                            "  delete)",
                            "       # Delete SNS Platform Application",
                            "       info \"Deleting SNS Platform App " + core.SubComponent.Name + "\" ",
                            "       delete_sns_platformapp" +
                            "       \"" + getRegion() + "\" " +
                            "       \"" + platformArn + "\" "
                            "   ;;",
                            "   esac"
                        ]
                /]
            [/#if]
        [/#if]
    [/#list]

    [#if hasPlatformApp ]
        [#if deploymentSubsetRequired( "prologue", false) ]
            [@addToDefaultBashScriptOutput
                content=
                    [
                        "# Mobile Notifier Cleanup",
                        "case $\{STACK_OPERATION} in",
                        "  create|update)",
                        "       info \"Cleaning up platforms that have been removed from config\"",
                        "       cleanup_sns_platformapps " +
                        "       \"" + getRegion() + "\" " +
                        "       \"" + platformAppName + "\" " +
                        "       '" + getJSON(deployedPlatformAppArns, false) + "' || return $?",
                        "       ;;",
                        "       esac"
                    ]

            /]
        [/#if]

        [#if deploymentSubsetRequired("iam", true)
            && isPartOfCurrentDeploymentUnit(roleId)]

            [@createRole
                id=roleId
                trustedServices=["sns.amazonaws.com" ]
                policies=
                    [
                        getPolicyDocument(
                                cwLogsProducePermission() +
                                cwLogsConfigurePermission(),
                            "logging")
                    ]
                tags=getOccurrenceTags(occurrence)
            /]
        [/#if]
    [/#if]
[/#macro]
