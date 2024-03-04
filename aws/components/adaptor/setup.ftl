[#ftl]
[#macro aws_adaptor_cf_deployment_generationcontract_application occurrence ]

    [#local converters = []]
    [#if occurrence.Configuration.Solution.Environment.FileFormat == "yaml" ]
        [#local converters += [ { "subset" : "config", "converter" : "config_yaml" }]]
    [/#if]

    [@addDefaultGenerationContract
        subsets=["deploymentcontract", "pregeneration", "config", "template", "prologue", "epilogue" ]
        converters=converters
    /]
[/#macro]

[#macro aws_adaptor_cf_deployment_deploymentcontract occurrence ]
    [@addDefaultAWSDeploymentContract prologue=true epilogue=true /]
[/#macro]

[#macro aws_adaptor_cf_deployment_application occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]
    [#local attributes = occurrence.State.Attributes ]
    [#local image =  getOccurrenceImage(occurrence)]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "OpsData", "AppData" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local operationsBucket = getExistingReference(baselineComponentIds["OpsData"]) ]

    [#if deploymentSubsetRequired("pregeneration", false) && image.Source == "url" ]
        [@addToDefaultBashScriptOutput
            content=getAWSImageFromUrlScript(image, true)
        /]
    [/#if]

    [#local asFiles = getAsFileSettings(occurrence.Configuration.Settings.Product) ]

    [#local contextLinks = getLinkTargets(occurrence) ]
    [#local _context =
        {
            "DefaultEnvironment" : defaultEnvironment(occurrence, contextLinks, baselineLinks),
            "Environment" : {},
            "ContextSettings" : {},
            "Links" : contextLinks,
            "BaselineLinks" : baselineLinks,
            "DefaultCoreVariables" : false,
            "DefaultEnvironmentVariables" : true,
            "DefaultLinkVariables" : false,
            "DefaultBaselineVariables" : false
        }
    ]
    [#local _context = invokeExtensions( occurrence, _context )]

    [#local EnvironmentSettings =
        {
            "Json" : {
                "Escaped" : false
            }
        }
    ]

    [#local finalEnvironment = getFinalEnvironment(occurrence, _context, EnvironmentSettings) ]

    [#local configFileFormat = solution.Environment.FileFormat ]
    [#switch configFileFormat ]
        [#case "json" ]
            [#local configFileName = "config.json"]
            [#break]
        [#case "yaml"]
            [#local configFileName = "config.yaml"]
            [#break]
    [/#switch]

    [#if deploymentSubsetRequired("config", false)]
        [@addToDefaultJsonOutput
            content=finalEnvironment.Environment
        /]
    [/#if]

    [#if deploymentSubsetRequired(ADAPTOR_COMPONENT_TYPE, true)]

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
                            dimensions=getCWMetricDimensions(alert, monitoredResource, resources, finalEnvironment)
                        /]
                    [#break]
                [/#switch]
            [/#list]
        [/#list]
    [/#if]

    [#if deploymentSubsetRequired("epilogue", false) ]
        [@addToDefaultBashScriptOutput
            content=
                ( image.Source != "none" )?then(
                    getAWSImageBuildScript(
                        "src_zip",
                        getRegion(),
                        image
                    ) +
                    [
                        "addToArray src \"$\{tmpdir}/src/\"",
                        "unzip \"$\{src_zip}\" -d \"$\{src}\""
                    ],
                    []
                ) +
                asFiles?has_content?then(
                     findAsFilesScript("filesToSync", asFiles) +
                        syncFilesToBucketScript(
                            "filesToSync",
                            getRegion(),
                            operationsBucket,
                            getOccurrenceSettingValue(occurrence, "SETTINGS_PREFIX")
                        ),
                     []
                ) +
                getLocalFileScript(
                    "config",
                    "$\{CONFIG}",
                    configFileName
                )
            section="1-Start"
        /]
    [/#if]
[/#macro]
