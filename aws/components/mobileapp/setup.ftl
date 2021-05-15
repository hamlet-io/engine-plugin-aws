[#ftl]
[#macro aws_mobileapp_cf_deployment_generationcontract_application occurrence ]
    [@addDefaultGenerationContract subsets=["pregeneration", "prologue", "config"] /]
[/#macro]

[#macro aws_mobileapp_cf_deployment_application occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]
    [#local attributes = occurrence.State.Attributes ]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "OpsData", "AppData" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local dataBucket = getExistingReference(baselineComponentIds["AppData"])]
    [#local operationsBucket = getExistingReference(baselineComponentIds["OpsData"]) ]

    [#local mobileAppId = resources["mobileapp"].Id]
    [#local configFilePath = resources["mobileapp"].ConfigFilePath ]
    [#local configFileName = resources["mobileapp"].ConfigFileName ]

    [#local buildReference = getOccurrenceBuildReference(occurrence)]
    [#local buildUnit = getOccurrenceBuildUnit(occurrence)]

    [#local imageSource = solution.Image.Source]

    [#if imageSource == "url" ]
        [#local buildUnit = occurrence.Core.Name ]
    [/#if]

    [#if deploymentSubsetRequired("pregeneration", false)]
        [#if imageSource = "url" ]
            [@addToDefaultBashScriptOutput
                content=
                    getImageFromUrlScript(
                        regionId,
                        productName,
                        environmentName,
                        segmentName,
                        occurrence,
                        solution.Image["Source:url"].Url,
                        "scripts",
                        "scripts.zip",
                        solution.Image["Source:url"].ImageHash,
                        true
                    )
            /]
        [/#if]
    [/#if]

    [#local codeSrcBucket = getRegistryEndPoint("scripts", occurrence)]
    [#local codeSrcPrefix = formatRelativePath(
                                    getRegistryPrefix("scripts", occurrence),
                                    getOccurrenceBuildProduct(occurrence, productName),
                                    getOccurrenceBuildScopeExtension(occurrence),
                                    buildUnit,
                                    buildReference
                                )]

    [#local buildConfig =
        {
            "RUN_ID"            : getCLORunId(),
            "CODE_SRC_BUCKET"   : codeSrcBucket,
            "CODE_SRC_PREFIX"   : codeSrcPrefix,
            "APP_BUILD_FORMATS" : solution.BuildFormats?join(","),
            "BUILD_REFERENCE"   : buildReference
        } +
        attributes +
        defaultEnvironment(occurrence, {}, baselineLinks)
    ]

    [#local contextLinks = getLinkTargets(occurrence) ]
    [#local _context =
        {
            "DefaultEnvironment" : defaultEnvironment(occurrence, contextLinks, baselineLinks),
            "Environment" : {},
            "Links" : contextLinks,
            "BaselineLinks" : baselineLinks,
            "DefaultCoreVariables" : false,
            "DefaultEnvironmentVariables" : true,
            "DefaultLinkVariables" : false,
            "DefaultBaselineVariables" : true
        }
    ]

    [#-- Add in extension specifics including override of defaults --]
    [#local _context = invokeExtensions( occurrence, _context )]

    [#local finalEnvironment = getFinalEnvironment(
            occurrence,
            _context,
            {
                "Json" : {
                    "Include" : {
                        "Sensitive" : false
                    }
                }
            }
    )]

    [#if deploymentSubsetRequired("config", false)]
        [@addToDefaultJsonOutput
            content={
                "BuildConfig" : buildConfig,
                "AppConfig" : finalEnvironment.Environment
            }
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
                        regionId,
                        operationsBucket,
                        getOccurrenceSettingValue(occurrence, "SETTINGS_PREFIX")
                    ) /]
        [/#if]

        [@addToDefaultBashScriptOutput
            content=
                getLocalFileScript(
                    "configFiles",
                    "$\{CONFIG}",
                    configFileName
                ) +
                syncFilesToBucketScript(
                    "configFiles",
                    regionId,
                    operationsBucket,
                    configFilePath
                ) /]
    [/#if]
[/#macro]
