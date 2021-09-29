[#ftl]
[#macro aws_adaptor_cf_deployment_generationcontract_application occurrence ]

    [#local converters = []]
    [#if occurrence.Configuration.Solution.Environment.FileFormat == "yaml" ]
        [#local converters += [ { "subset" : "config", "converter" : "config_yaml" }]]
    [/#if]

    [@addDefaultGenerationContract
        subsets=["pregeneration", "config", "template", "prologue", "epilogue" ]
        converters=converters
    /]
[/#macro]

[#macro aws_adaptor_cf_deployment_application occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]
    [#local attributes = occurrence.State.Attributes ]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "OpsData", "AppData" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local operationsBucket = getExistingReference(baselineComponentIds["OpsData"]) ]

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
                        getRegion(),
                        productName,
                        environmentName,
                        segmentName,
                        occurrence,
                        solution.Image.UrlSource.Url,
                        "scripts",
                        "scripts.zip",
                        solution.Image.UrlSource.ImageHash,
                        true
                    )
            /]
        [/#if]
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

    [#if deploymentSubsetRequired("epilogue", false) ]
        [@addToDefaultBashScriptOutput
            content=
                ( imageSource != "none" )?then(
                    getBuildScript(
                        "src_zip",
                        getRegion(),
                        "scripts",
                        productName,
                        occurrence,
                        "scripts.zip",
                        buildUnit
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
