[#ftl]
[#macro aws_lambda_cf_deployment_generationcontract_application occurrence ]

    [#local converters = []]
    [#list occurrence.Occurrences as subOccurrence ]
        [#if subOccurrence.Configuration.Solution.Environment.FileFormat == "yaml" ]
            [#local converters = [ { "subset" : "config", "converter" : "config_yaml" }]]
        [/#if]
    [/#list]

    [@addDefaultGenerationContract subsets=[ "pregeneration", "prologue", "template", "config", "epilogue"] converters=converters /]
[/#macro]

[#macro aws_lambda_cf_deployment_application occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#list occurrence.Occurrences as fn]
        [@internalProcessFunction fn /]
    [/#list]
[/#macro]

[#-- Rename once we switch to the context model for processing --]
[#macro aws_functionxx_cf_deployment_application occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#if deploymentSubsetRequired("generationcontract", false)]
        [@addDefaultGenerationContract subsets=[ "pregeneration", "prologue", "template", "config", "epilogue"] /]
        [#return]
    [/#if]

    [@internalProcessFunction occurrence /]
[/#macro]

[#macro internalProcessFunction fn ]

    [#local core = fn.Core ]
    [#local solution = fn.Configuration.Solution ]
    [#local resources = fn.State.Resources ]

    [#local deploymentType = solution.DeploymentType ]

    [#local fnId = resources["function"].Id ]
    [#local fnName = resources["function"].Name ]

    [#local fnLgId = resources["lg"].Id ]
    [#local fnLgName = resources["lg"].Name ]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(fn, [ "OpsData", "AppData", "Encryption" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]

    [#local cmkKeyId = baselineComponentIds["Encryption" ]]
    [#local operationsBucket = getExistingReference(baselineComponentIds["OpsData"]) ]
    [#local dataBucket = getExistingReference(baselineComponentIds["AppData"])]

    [#local loggingProfile = getLoggingProfile(fn)]

    [#local vpcAccess = solution.VPCAccess ]
    [#if vpcAccess ]
        [#local networkLink = getOccurrenceNetwork(fn).Link!{} ]

        [#local networkLinkTarget = getLinkTarget(fn, networkLink ) ]
        [#if ! networkLinkTarget?has_content ]
            [@fatal message="Network could not be found" context=networkLink /]
            [#return]
        [/#if]

        [#local networkConfiguration = networkLinkTarget.Configuration.Solution]
        [#local networkResources = networkLinkTarget.State.Resources ]

        [#local networkProfile = getNetworkProfile(fn)]

        [#local vpcId = networkResources["vpc"].Id ]
        [#local vpc = getExistingReference(vpcId)]

        [#local securityGroupId = resources["securityGroup"].Id ]
        [#local securityGroupName = resources["securityGroup"].Name ]
    [/#if]

    [#local buildReference = getOccurrenceBuildReference(fn)]
    [#local buildUnit = getOccurrenceBuildUnit(fn)]

    [#local imageSource = solution.Image.Source]
    [#if imageSource == "url" ]
        [#local buildUnit = fn.Core.Name ]
    [/#if]

    [#if deploymentSubsetRequired("pregeneration", false) && imageSource == "url" ]
        [@addToDefaultBashScriptOutput
            content=
                getImageFromUrlScript(
                    regionId,
                    productName,
                    environmentName,
                    segmentName,
                    fn,
                    solution.Image.UrlSource.Url,
                    "lambda",
                    "lambda.zip",
                    solution.Image.UrlSource.ImageHash
                )
        /]
    [/#if]

    [#local contextLinks = getLinkTargets(fn) ]
    [#local _context =
        {
            "DefaultEnvironment" : defaultEnvironment(fn, contextLinks, baselineLinks),
            "Environment" : {},
            "S3Bucket" : getRegistryEndPoint("lambda", fn),
            "S3Key" :
                formatRelativePath(
                    getRegistryPrefix("lambda", fn),
                    getOccurrenceBuildProduct(fn,productName),
                    getOccurrenceBuildScopeExtension(fn),
                    buildUnit,
                    buildReference,
                    "lambda.zip"
                ),
            "Links" : contextLinks,
            "BaselineLinks" : baselineLinks,
            "DefaultCoreVariables" : true,
            "DefaultEnvironmentVariables" : true,
            "DefaultLinkVariables" : true,
            "DefaultBaselineVariables" : true,
            "Policy" : standardPolicies(fn, baselineComponentIds),
            "ManagedPolicy" : [],
            "CodeHash" : solution.FixedCodeVersion.CodeHash,
            "VersionDependencies" : [],
            "CreateVersionInExtension" : false
        }
    ]
    [#local _context = invokeExtensions( fn, _context )]

    [#if deploymentSubsetRequired("lambda", true)]
        [#list _context.Links as linkName,linkTarget]

            [#local linkTargetCore = linkTarget.Core ]
            [#local linkTargetConfiguration = linkTarget.Configuration ]
            [#local linkTargetResources = linkTarget.State.Resources ]
            [#local linkTargetAttributes = linkTarget.State.Attributes ]
            [#local linkTargetRoles = linkTarget.State.Roles ]
            [#local linkDirection = linkTarget.Direction ]
            [#local linkRole = linkTarget.Role]

            [#if vpcAccess ]
                [@createSecurityGroupRulesFromLink
                    occurrence=fn
                    groupId=securityGroupId
                    linkTarget=linkTarget
                    inboundPorts=[]
                    networkProfile=networkProfile
                /]
            [/#if]

            [#switch linkDirection ]
                [#case "inbound" ]
                    [#switch linkRole ]
                        [#case "invoke" ]
                            [#switch linkTargetCore.Type]
                                [#case USERPOOL_COMPONENT_TYPE ]
                                [#case LAMBDA_FUNCTION_COMPONENT_TYPE ]
                                [#case APIGATEWAY_COMPONENT_TYPE ]
                                [#case TOPIC_COMPONENT_TYPE]
                                [#case S3_COMPONENT_TYPE ]
                                [#case MTA_RULE_COMPONENT_TYPE ]
                                    [@createLambdaPermission
                                        id=formatLambdaPermissionId(fn, "link", linkName)
                                        targetId=fnId
                                        source=linkTargetRoles.Inbound["invoke"]
                                    /]
                                    [#break]

                            [/#switch]
                            [#break]

                        [#case "authorise" ]
                        [#case "authorize" ]
                            [#switch linkTargetCore.Type]
                                 [#case APIGATEWAY_COMPONENT_TYPE ]
                                    [@createLambdaPermission
                                        id=formatLambdaPermissionId(fn, "link", linkName)
                                        targetId=fnId
                                        source=linkTargetRoles.Inbound["authorize"]
                                    /]
                                    [#break]

                            [/#switch]
                            [#break]

                    [/#switch]
                    [#break]
                [#case "outbound" ]
                    [#switch linkRole ]
                        [#case "event" ]
                            [#switch linkTargetCore.Type ]
                                [#case SQS_COMPONENT_TYPE ]
                                    [#if linkTargetAttributes["ARN"]?has_content ]
                                        [@createLambdaEventSource
                                            id=formatLambdaEventSourceId(fn, "link", linkName)
                                            targetId=fnId
                                            source=linkTargetAttributes["ARN"]
                                            batchSize=1
                                        /]
                                    [/#if]
                                    [#break]
                                [#case TOPIC_COMPONENT_TYPE ]
                                    [#if linkTargetAttributes["ARN"]?has_content ]
                                        [@createSNSSubscription
                                            id=formatDependentSNSSubscriptionId(fn, "link", linkName)
                                            topicId=linkTargetResources["topic"].Id
                                            endpoint=getReference(fnId, ARN_ATTRIBUTE_TYPE)
                                            protocol="lambda"
                                        /]
                                    [/#if]
                                    [#break]
                            [/#switch]
                            [#break]
                    [/#switch]
                    [#break]
            [/#switch]
        [/#list]
    [/#if]

    [#-- clear all environment variables for EDGE deployments --]
    [#if deploymentType == "EDGE" ]
        [#local _context += {
            "DefaultEnvironment" : {},
            "Environment" : {},
            "DefaultCoreVariables" : false,
            "DefaultEnvironmentVariables" : false,
            "DefaultLinkVariables" : false,
            "DefaultBaselineVariables" : false
        }]
    [/#if]

    [#local finalEnvironment = getFinalEnvironment(fn, _context, solution.Environment) ]
    [#local finalAsFileEnvironment = getFinalEnvironment(fn, _context, solution.Environment + {"AsFile" : false}) ]
    [#local asFileFormat = solution.Environment.FileFormat ]
    [#switch asFileFormat ]
        [#case "json" ]
            [#local asFileSuffix = ".json"]
            [#break]
        [#case "yaml"]
            [#local asFileSuffix = ".yaml"]
            [#break]
    [/#switch]

    [#local _context += finalEnvironment ]

    [#-- AWS has a 4k limit on the size of the environment - check how close we are --]
    [#local envSize = getJSON(finalEnvironment)?length]
    [#local sizeRemedy = "One solution might be to limit the attributes included on links via the IncludeInContext attribute" ]
    [#-- Not clear what AWS counts in the 4k limit but this should be close --]
    [#if envSize > 4096]
        [@fatal
            message="Lambda environment size of " + envSize?c + " exceeds the AWS limit of 4096"
            detail=sizeRemedy
        /]
    [#-- It is a bit arbitrary as to what defines close --]
    [#elseif envSize > 3896]
        [@warn
            message="Lambda environment size of " + envSize?c + " is close to the AWS limit of 4096"
            detail=sizeRemedy
        /]
    [/#if]

    [#local roleId = formatDependentRoleId(fnId)]
    [#local managedPolicies =
        (vpcAccess)?then(
            ["arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"],
            ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]
        ) +
        (solution.Tracing.Configured && solution.Tracing.Enabled)?then(
            ["arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"],
            []
        ) +
        _context.ManagedPolicy ]

    [#local linkPolicies = getLinkTargetsOutboundRoles(_context.Links) ]

    [#-- Ensure policies are ignored as dependencies unless created as part of this template --]
    [#local policyId = ""]
    [#local linkPolicyId = ""]

    [#if deploymentSubsetRequired("iam", true) && isPartOfCurrentDeploymentUnit(roleId)]

        [#-- Create a role under which the function will run and attach required policies --]
        [#-- The role is mandatory though there may be no policies attached to it --]
        [@createRole
            id=roleId
            trustedServices=[
                "lambda.amazonaws.com"
            ] +
            (deploymentType == "EDGE")?then(
                [
                    "edgelambda.amazonaws.com"
                ],
                []
            )
            managedArns=managedPolicies

        /]

        [#if _context.Policy?has_content]
            [#local policyId = formatDependentPolicyId(fnId)]
            [@createPolicy
                id=policyId
                name=_context.Name
                statements=_context.Policy
                roles=roleId
            /]
        [/#if]

        [#if linkPolicies?has_content]
            [#local linkPolicyId = formatDependentPolicyId(fnId, "links")]
            [@createPolicy
                id=linkPolicyId
                name="links"
                statements=linkPolicies
                roles=roleId
            /]
        [/#if]
    [/#if]

    [#if deploymentType == "REGIONAL" &&
            solution.PredefineLogGroup ]
        [@setupLogGroup
            occurrence=fn
            logGroupId=fnLgId
            logGroupName=fnLgName
            loggingProfile=loggingProfile
        /]
    [/#if]


    [#if isPresent(solution.FixedCodeVersion) ]
        [#local versionId = resources["version"].Id  ]
        [#local versionResourceId = resources["version"].ResourceId ]

        [#if !(core.Version?has_content)]
            [@fatal
                message="A component version must be defined for Fixed Code Version deployments"
                context=core
            /]
        [/#if]

        [#if !(_context.CreateVersionInExtension) && deploymentSubsetRequired("lambda", true)]
            [@createLambdaVersion
                id=versionResourceId
                targetId=fnId
                codeHash=_context.CodeHash!""
                outputId=versionId
            /]
        [/#if]
    [/#if]

    [#if deploymentSubsetRequired("lambda", true)]
        [#-- VPC config uses an ENI so needs an SG - create one without restriction --]
        [#if vpcAccess ]
            [@createSecurityGroup
                id=securityGroupId
                name=securityGroupName
                vpcId=vpcId
                occurrence=fn
            /]

            [@createSecurityGroupRulesFromNetworkProfile
                occurrence=fn
                groupId=securityGroupId
                networkProfile=networkProfile
                inboundPorts=[]
            /]
        [/#if]

        [#if solution.PredefineLogGroup && deploymentType == "REGIONAL"]
            [#list resources.logMetrics!{} as logMetricName,logMetric ]

                [@createLogMetric
                    id=logMetric.Id
                    name=logMetric.Name
                    logGroup=logMetric.LogGroupName
                    filter=logFilters[logMetric.LogFilter].Pattern
                    namespace=getCWResourceMetricNamespace(logMetric.Type)
                    value=1
                    dependencies=logMetric.LogGroupId
                /]

            [/#list]
        [/#if]

        [@createLambdaFunction
            id=fnId
            settings=_context +
                {
                    "Handler" : solution.Handler,
                    "RunTime" : solution.RunTime,
                    "MemorySize" : solution.Memory,
                    "Timeout" : solution.Timeout,
                    "Encrypted" : solution.Encrypted,
                    "KMSKeyId" : cmkKeyId,
                    "Name" : fnName,
                    "Description" : fnName,
                    "Tracing" : solution.Tracing,
                    "ReservedExecutions" : solution.ReservedExecutions
                }
            roleId=roleId
            securityGroupIds=
                (vpcAccess)?then(
                    formatDependentSecurityGroupId(fnId),
                    []
                )
            subnetIds=
                (vpcAccess)?then(
                    getSubnets(core.Tier, networkResources, "", false),
                    []
                )
            dependencies=
                [roleId, policyId, linkPolicyId] +
                valueIfTrue([fnLgId], solution.PredefineLogGroup, [])
        /]

        [#if deploymentType == "EDGE" ]

            [#if !isPresent(solution.FixedCodeVersion) ]
                [@fatal
                    message="EDGE based deployments must be deployed as Fixed code version deployments"
                    context=_context
                    detail="Lambda@Edge deployments are based on a snapshot of lambda code and a specific hamlet version is required "
                /]
            [/#if]

            [#if !(_context.CreateVersionInExtension) ]
                [@createLambdaPermission
                    id=formatLambdaPermissionId(fn, "replication")
                    action="lambda:GetFunction"
                    targetId=versionResourceId
                    source={
                        "Principal" : "replicator.lambda.amazonaws.com"
                    }
                    sourceId=scheduleRuleId
                    dependencies=scheduleRuleId
                /]
            [/#if]
        [/#if]

        [#list solution.Schedules?values as schedule ]

            [#local scheduleRuleId = formatEventRuleId(fn, "schedule", schedule.Id) ]

            [#local targetParameters = {
                "Arn" : getReference(fnId, ARN_ATTRIBUTE_TYPE),
                "Id" : fnId,
                "Input" : getJSON(schedule.Input?has_content?then(schedule.Input,{ "path" : schedule.InputPath }))
            }]

            [@createScheduleEventRule
                id=scheduleRuleId
                enabled=schedule.Enabled
                scheduleExpression=schedule.Expression
                targetParameters=targetParameters
                dependencies=fnId
            /]

            [@createLambdaPermission
                id=formatLambdaPermissionId(fn, "schedule", schedule.Id)
                targetId=fnId
                sourcePrincipal="events.amazonaws.com"
                sourceId=scheduleRuleId
                dependencies=scheduleRuleId
            /]
        [/#list]

        [#list solution.LogWatchers as logWatcherName,logwatcher ]

            [#local logFilter = logFilters[logwatcher.LogFilter].Pattern ]

            [#list logwatcher.Links as logWatcherLinkName,logWatcherLink ]
                [#local logWatcherLinkTarget = getLinkTarget(fn, logWatcherLink) ]

                [#if !logWatcherLinkTarget?has_content]
                    [#continue]
                [/#if]

                [#local roleSource = logWatcherLinkTarget.State.Roles.Inbound["logwatch"]]

                [#list asArray(roleSource.LogGroupIds) as logGroupId ]

                    [#local logGroupArn = getExistingReference(logGroupId, ARN_ATTRIBUTE_TYPE)]

                    [#if logGroupArn?has_content ]

                        [@createLambdaPermission
                            id=formatLambdaPermissionId(fn, "logwatch", logWatcherLink.Id, logGroupId?index)
                            targetId=fnId
                            source={
                                "Principal" : roleSource.Principal,
                                "SourceArn" : logGroupArn
                            }
                            dependencies=fnId
                        /]

                        [@createLogSubscription
                            id=formatDependentLogSubscriptionId(fnId, logWatcherLink.Id, logGroupId?index)
                            logGroupName=getExistingReference(logGroupId)
                            logFilterId=logFilter
                            destination=fnId
                            dependencies=fnId
                        /]

                    [/#if]
                [/#list]
            [/#list]
        [/#list]

        [#list solution.Alerts?values as alert ]

            [#local monitoredResources = getCWMonitoredResources(core.Id, resources, alert.Resource)]
            [#list monitoredResources as name,monitoredResource ]

                [#switch alert.Comparison ]
                    [#case "Threshold" ]
                        [@createAlarm
                            id=formatDependentAlarmId(monitoredResource.Id, alert.Id )
                            severity=alert.Severity
                            resourceName=core.FullName
                            alertName=alert.Name
                            actions=getCWAlertActions(fn, solution.Profiles.Alert, alert.Severity )
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
                            dimensions=getCWMetricDimensions(alert, monitoredResource, resources, finalAsFileEnvironment)
                        /]
                    [#break]
                [/#switch]
            [/#list]
        [/#list]
    [/#if]
    [#if solution.Environment.AsFile && deploymentSubsetRequired("config", false)]
        [@addToDefaultJsonOutput content=finalAsFileEnvironment.Environment /]
    [/#if]
    [#if deploymentSubsetRequired("prologue", false)]
        [#-- Copy any asFiles needed by the task --]
        [#local asFiles = getAsFileSettings(fn.Configuration.Settings.Product) ]
        [#if asFiles?has_content]
            [@debug message="Asfiles" context=asFiles enabled=false /]
            [@addToDefaultBashScriptOutput
                content=
                    findAsFilesScript("filesToSync", asFiles) +
                    syncFilesToBucketScript(
                        "filesToSync",
                        regionId,
                        operationsBucket,
                        getOccurrenceSettingValue(fn, "SETTINGS_PREFIX"),
                        false
                    ) /]
        [/#if]
        [#if solution.Environment.AsFile]
            [@addToDefaultBashScriptOutput
                content=
                    getLocalFileScript(
                        "configFiles",
                        "$\{CONFIG}",
                        "config_" + getCLORunId() + asFileSuffix
                    ) +
                    syncFilesToBucketScript(
                        "configFiles",
                        regionId,
                        operationsBucket,
                        formatRelativePath(
                            getOccurrenceSettingValue(fn, "SETTINGS_PREFIX"),
                            "config"
                        ),
                        false
                    ) /]
        [/#if]
        [@addToDefaultBashScriptOutput
            content=(vpcAccess)?then(
                [
                    "case $\{STACK_OPERATION} in",
                    "  delete)"
                ] +
                [
                    "# Release ENIs",
                    "info \"Releasing ENIs ... \"",
                    "release_enis" +
                    " \"" + regionId + "\" " +
                    " \"" + fnName + "\" || return $?"

                ] +
                [
                    "       ;;",
                    "       esac"
                ],
                []
            )
        /]
    [/#if]

    [#-- Always exclude any reference files copied by other deployments      --]
    [#-- An example use case is the api gateway copying an openapi.json file --]
    [#-- for a lambda authoriser                                             --]
    [#local syncExclusions =
        ["reference/*"] +
        arrayIfTrue(
            "config/*",
            solution.Environment.AsFile
        )
    ]

    [#if deploymentSubsetRequired("epilogue", false)]
        [#-- Assume stack update was successful so delete other files --]
        [#local asFiles = getAsFileSettings(fn.Configuration.Settings.Product) ]
        [#if asFiles?has_content]
            [@debug message="Asfiles" context=asFiles enabled=false /]
            [@addToDefaultBashScriptOutput
                content=
                    findAsFilesScript("filesToSync", asFiles) +
                    syncFilesToBucketScript(
                        "filesToSync",
                        regionId,
                        operationsBucket,
                        getOccurrenceSettingValue(fn, "SETTINGS_PREFIX"),
                        true,
                        syncExclusions
                    ) /]
        [/#if]
        [#if solution.Environment.AsFile]
            [@addToDefaultBashScriptOutput
                content=
                    getLocalFileScript(
                        "configFiles",
                        "$\{CONFIG}",
                        "config_" + getCLORunId() + asFileSuffix
                    ) +
                    syncFilesToBucketScript(
                        "configFiles",
                        regionId,
                        operationsBucket,
                        formatRelativePath(
                            getOccurrenceSettingValue(fn, "SETTINGS_PREFIX"),
                            "config"
                        ),
                        true
                    ) /]
        [/#if]
    [/#if]

[/#macro]
