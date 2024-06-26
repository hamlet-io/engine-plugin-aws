[#ftl]
[#macro aws_healthcheck_cf_deployment_generationcontract occurrence ]
    [@addDefaultGenerationContract
        subsets=[ "deploymentcontract", "prologue", "template", "epilogue" ]
    /]
[/#macro]

[#macro aws_healthcheck_cf_deployment_deploymentcontract occurrence ]
    [@addDefaultAWSDeploymentContract prologue=true epilogue=true /]
[/#macro]

[#macro aws_healthcheck_cf_deployment occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]
    [#local resources = occurrence.State.Resources]
    [#local links = solution.Links ]

    [#-- Health checks as a single deployment are generally run from multiple regions to check availability over the internet --]
    [#local checkRegionIds = []]
    [#local regionIds = []]

    [#list solution.Regions as region ]
        [#switch region ]
            [#case "_product" ]
                [#local regionIds += [ getRegion() ]]
                [#break]

            [#case "_all"]
                [#local regionIds += aws_cmdb_regions?keys ]
                [#break]

            [#default]
                [#local regionIds += [
                            (((aws_cmdb_regions[region])!{})
                                ?has_content)
                                ?then(
                                    region,
                                    ""
                                )
                        ]]
        [/#switch]
    [/#list]

    [#list regionIds as region ]
        [#if region?has_content ]
            [#local checkRegionIds = combineEntities( checkRegionIds, region, UNIQUE_COMBINE_BEHAVIOUR )]
        [/#if]
    [/#list]

    [#switch solution.Engine ]
        [#case "Simple" ]

            [#local healthCheckId = resources["healthcheck"].Id ]
            [#local healthCheckName = resources["healthcheck"].Name ]

            [#local address = ""]

            [#local destination = solution["Engine:Simple"]["Destination"] ]
            [#local destinationLink = (destination["Link"])!{} ]
            [#local explicitAddress = (destination["Address"])!"" ]

            [#if getRegion() != "us-east-1" ]
                [@fatal
                    message="Simple Health checks must be deployed to us-east-1 in AWS"
                    context={
                        "HealthCheckId" : occurrence.Core.Id,
                        "Region" : getRegion()
                    }
                /]
            [/#if]

            [#if deploymentSubsetRequired(HEALTHCHECK_COMPONENT_TYPE, true) ]
                [#if isPresent(destinationLink) && ! (explicitAddress?has_content) ]
                    [#local destinationLinkTarget = getLinkTarget(occurrence, destinationLink )]

                    [#local addressAttribute = solution["Engine:Simple"]["Destination"]["LinkAttribute"] ]
                    [#if destinationLinkTarget?has_content ]
                        [#local address = (destinationLinkTarget.State.Attributes[addressAttribute])!"" ]
                    [/#if]
                [/#if]

                [#if explicitAddress?has_content ]
                    [#local address = explicitAddress ]
                [/#if]

                [#if ! (address?has_content) ]
                    [@fatal
                        message="Address could not be found for health check"
                        detail="Check the destination has been deployed and LinkAttribute set or that the Address has been provided"
                        context={
                            "HealthCheckId" : core.Id,
                            "Destination" : destination
                        }
                    /]
                [/#if]

                [#local portName = (solution["Engine:Simple"]["Port"])!"" ]
                [#local monitorPort = {}]
                [#if portName?has_content ]
                    [#local monitorPort = (ports[portName])!{} ]
                [/#if]

                [#if ! (monitorPort?has_content)]
                    [@fatal
                        message="Monitor port could not be found or was mssing"
                        detail={ "Port" : portName }
                        context={
                            "HealthCheckId" : core.Id,
                            "Configuration" : solution
                        }
                    /]
                [/#if]

                [#local searchString = solution["Engine:Simple"]["HTTPSearchString"] ]
                [#if solution["Engine:Simple"]["HTTPSearchSetting"]?? ]
                    [#local searchString =
                        getOccurrenceSettingValue(occurrence, solution["Engine:Simple"]["HTTPSearchSetting"], true) ]
                [/#if]

                [@createRoute53HealthCheck
                    id=healthCheckId
                    name=healthCheckName
                    port=monitorPort
                    addressType=destination.AddressType
                    address=address
                    regions=checkRegionIds
                    searchString=searchString
                    tags=getOccurrenceTags(occurrence)
                /]
            [/#if]
            [#break]

        [#case "Complex"]

            [#local canaryId = resources["canary"].Id ]
            [#local canaryName = resources["canary"].Name ]
            [#local roleId = resources["role"].Id ]
            [#local image =  getOccurrenceImage(occurrence)]

            [#-- Baseline component lookup --]
            [#local baselineLinks = getBaselineLinks(occurrence, [ "OpsData", "AppData", "Encryption" ] )]
            [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]

            [#local cmkKeyId = baselineComponentIds["Encryption" ]]
            [#local operationsBucket = getExistingReference(baselineComponentIds["OpsData"]) ]
            [#local dataBucket = getExistingReference(baselineComponentIds["AppData"])]

            [#local scriptsPrefix = formatRelativePath(
                                    getAppDataFilePrefix(occurrence),
                                    "scripts"
                                )]

            [#local scriptFile = formatRelativePath(
                                    scriptsPrefix,
                                    solution["Engine:Complex"]["ScriptFileName"]
            )]

            [#local vpcAccess = solution.NetworkAccess ]
            [#if vpcAccess ]
                [#local networkLink = getOccurrenceNetwork(occurrence).Link!{} ]

                [#local networkLinkTarget = getLinkTarget(occurrence, networkLink ) ]
                [#if ! networkLinkTarget?has_content ]
                    [@fatal message="Network could not be found" context=networkLink /]
                    [#return]
                [/#if]

                [#local networkConfiguration = networkLinkTarget.Configuration.Solution]
                [#local networkResources = networkLinkTarget.State.Resources ]

                [#local networkProfile = getNetworkProfile(occurrence)]

                [#local vpcId = networkResources["vpc"].Id ]
                [#local vpc = getExistingReference(vpcId)]

                [#local securityGroupId = resources["securityGroup"].Id ]
                [#local securityGroupName = resources["securityGroup"].Name ]
            [/#if]

    [#if deploymentSubsetRequired("pregeneration", false) && image.Source == "url" ]
        [@addToDefaultBashScriptOutput
            content=getAWSImageFromUrlScript(image, true)
        /]
    [/#if]

            [#local contextLinks = getLinkTargets(occurrence) ]
            [#local _context =
                {
                    "DefaultEnvironment" : defaultEnvironment(occurrence, contextLinks, baselineLinks),
                    "Environment" : {},
                    "S3Bucket" : (image.ImageLocation?remove_beginning("s3://")?keep_before("/"))!"",
                    "S3Key" : (image.ImageLocation?remove_beginning("s3://")?keep_after("/"))!"",
                    "Links" : contextLinks,
                    "BaselineLinks" : baselineLinks,
                    "DefaultCoreVariables" : false,
                    "DefaultEnvironmentVariables" : false,
                    "DefaultLinkVariables" : false,
                    "DefaultBaselineVariables" : false,
                    "Policy" : iamStandardPolicies(occurrence, baselineComponentIds),
                    "ManagedPolicy" : [],
                    "Script" : []
                }
            ]
            [#local _context = invokeExtensions( occurrence, _context )]

            [#local finalEnvironment = getFinalEnvironment(occurrence, _context, solution.Environment) ]
            [#local _context += finalEnvironment ]

            [#if deploymentSubsetRequired(HEALTHCHECK_COMPONENT_TYPE, true)]
                [#list _context.Links as linkName,linkTarget]

                    [#if vpcAccess ]
                        [@createSecurityGroupRulesFromLink
                            occurrence=occurrence
                            groupId=securityGroupId
                            linkTarget=linkTarget
                            inboundPorts=[]
                            networkProfile=networkProfile
                        /]
                    [/#if]
                [/#list]
            [/#if]

            [#local managedPolicies =
                (vpcAccess)?then(
                    ["arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"],
                    []
                ) +
                (solution["Engine:Complex"].Tracing.Configured && solution["Engine:Complex"].Tracing.Enabled)?then(
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
                    ]
                    managedArns=managedPolicies
                    tags=getOccurrenceTags(occurrence)
                /]

                [@createPolicy
                    id=formatDependentPolicyId(canaryId, "base")
                    roles=roleId
                    name="base"
                    statements=[
                        getPolicyStatement(
                            [
                                "cloudwatch:PutMetricData"
                            ]
                            "*",
                            "",
                            {
                                "StringEquals": {
                                    "cloudwatch:namespace": "CloudWatchSynthetics"
                                }
                            }
                        ),
                        getPolicyStatement(
                            [
                                "logs:CreateLogStream",
                                "logs:PutLogEvents",
                                "logs:CreateLogGroup"
                            ],
                            {
                                "Fn::Sub" : [
                                    r'arn:aws:logs:${Region}:${AWSAccountId}:log-group:/aws/lambda/cwsyn-*',
                                    {
                                        "Region" : {
                                            "Ref" : "AWS::Region"
                                        },
                                        "AWSAccountId" : {
                                            "Ref" : "AWS::AccountId"
                                        }
                                    }
                                ]
                            }
                        ),
                        getPolicyStatement(
                            [
                                "s3:ListAllMyBuckets",
                                "xray:PutTraceSegments"
                            ],
                            "*"
                        ),
                        getPolicyStatement(
                            [
                                "s3:PutObject"
                            ],
                            {
                                "Fn::Sub" : [
                                    r'arn:aws:s3:::cw-syn-results-${Account}-${Region}/canary/${Region}/*',
                                    {
                                        "Region" : {
                                            "Ref" : "AWS::Region"
                                        },
                                        "Account" : {
                                            "Ref" : "AWS::AccountId"
                                        }
                                    }
                                ]
                            }
                        ),
                        getPolicyStatement(
                            [
                                "s3:GetBucketLocation"
                            ],
                            {
                                "Fn::Sub" : [
                                    r'arn:aws:s3:::cw-syn-results-${Account}-${Region}',
                                    {
                                        "Region" : {
                                            "Ref" : "AWS::Region"
                                        },
                                        "Account" : {
                                            "Ref" : "AWS::AccountId"
                                        }
                                    }
                                ]
                            }
                        )
                    ]
                /]

                [#if _context.Policy?has_content]
                    [#local policyId = formatDependentPolicyId(canaryId)]
                    [@createPolicy
                        id=policyId
                        name=_context.Name
                        statements=_context.Policy
                        roles=roleId
                    /]
                [/#if]

                [#if linkPolicies?has_content]
                    [#local linkPolicyId = formatDependentPolicyId(canaryId, "links")]
                    [@createPolicy
                        id=linkPolicyId
                        name="links"
                        statements=linkPolicies
                        roles=roleId
                    /]
                [/#if]
            [/#if]

            [#if deploymentSubsetRequired(HEALTHCHECK_COMPONENT_TYPE, true)]

                [#if vpcAccess ]
                    [@createSecurityGroup
                        id=securityGroupId
                        name=securityGroupName
                        vpcId=vpcId
                        tags=getOccurrenceTags(occurrence)
                    /]

                    [@createSecurityGroupRulesFromNetworkProfile
                        occurrence=occurrence
                        groupId=securityGroupId
                        networkProfile=networkProfile
                        inboundPorts=[]
                    /]
                [/#if]

                [#local script = ""]
                [#local scriptBucket = ""]
                [#local scriptFilePrefix = ""]

                [#local handler = solution["Engine:Complex"].Handler]

                [#if image.Source == "none" ]
                    [#if _context.Script?has_content ]

                        [#local script = asArray(_context.Script)?join("\n")]

                        [#-- Set the handler to the standard value that cloudwatch creates --]
                        [#local handler = handler
                                            ?keep_after_last(".")
                                            ?ensure_starts_with("pageLoadBlueprint.") ]
                    [/#if]
                [/#if]

                [#if ! (script?has_content) ]
                    [#local scriptBucket = _context.S3Bucket ]
                    [#local scriptFilePrefix = _context.S3Key ]
                [/#if]

                [@createCWCanary
                    id=canaryId
                    name=canaryName
                    handler=solution["Engine:Complex"].Handler
                    artifactS3Url=formatRelativePath("s3://", dataBucket, getAppDataFilePrefix(occurrence))
                    roleId=roleId
                    runTime=solution["Engine:Complex"].RunTime
                    scheduleExpression=solution["Engine:Complex"].Schedule
                    memory=solution["Engine:Complex"].Memory
                    activeTracing=solution["Engine:Complex"].Tracing.Enabled
                    environment=finalEnvironment.Environment
                    successRetention=solution.ReportRetention.Success
                    failureRetention=solution.ReportRetention.Failure
                    vpcEnabled=vpcAccess
                    securityGroupIds=vpcAccess?then([ getReference(securityGroupId) ], [])
                    subnets=vpcAccess?then(getSubnets(core.Tier, networkResources), [])
                    vpcId=vpcAccess?then(vpcId, "")
                    tags=getOccurrenceTags(occurrence)
                    script=script
                    s3Bucket=scriptBucket
                    s3Key=scriptFilePrefix
                /]

            [/#if]

            [#if deploymentSubsetRequired("prologue", false)]
                [#-- Copy any asFiles needed by the task --]
                [#local asFiles = getAsFileSettings(occurrence.Configuration.Settings.Product) ]
                [#if asFiles?has_content]
                    [@debug message="Asfiles" context=asFiles enabled=false /]
                    [@addToDefaultBashScriptOutput
                        content=
                            findAsFilesScript("filesToSync", asFiles) +
                            syncFilesToBucketScript(
                                "filesToSync",
                                getRegion(),
                                operationsBucket,
                                getOccurrenceSettingValue(occurrence, "SETTINGS_PREFIX"),
                                false
                            )
                    /]
                [/#if]
            [/#if]

            [#if deploymentSubsetRequired("epilogue", false)]
                [#-- Assume stack update was successful so delete other files --]
                [#local asFiles = getAsFileSettings(occurrence.Configuration.Settings.Product) ]
                [#if asFiles?has_content]
                    [@debug message="Asfiles" context=asFiles enabled=false /]
                    [@addToDefaultBashScriptOutput
                        content=
                            findAsFilesScript("filesToSync", asFiles) +
                            syncFilesToBucketScript(
                                "filesToSync",
                                getRegion(),
                                operationsBucket,
                                getOccurrenceSettingValue(occurrence, "SETTINGS_PREFIX"),
                                true
                            )
                    /]
                [/#if]
            [/#if]
            [#break]
    [/#switch]


    [#if deploymentSubsetRequired(HEALTHCHECK_COMPONENT_TYPE, true) ]
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
    [/#if]

[/#macro]
