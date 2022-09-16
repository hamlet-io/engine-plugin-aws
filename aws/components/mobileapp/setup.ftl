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
                        getRegion(),
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
            "BUILD_REFERENCE"   : buildReference,
            "APP_REFERENCE"     : (occurrence.Configuration.Settings.Build.APP_REFERENCE.Value)!"",
            "OPSDATA_BUCKET"    : operationsBucket,
            "SETTINGS_PREFIX"   : getSettingsFilePrefix(occurrence),
            "APPDATA_BUCKET"    : dataBucket,
            "APPDATA_PREFIX"    : getAppDataFilePrefix(occurrence),

            "CODE_SRC_BUCKET"   : codeSrcBucket,
            "CODE_SRC_PREFIX"   : codeSrcPrefix,
            "APP_BUILD_FORMATS" : solution.BuildFormats?join(","),
            "KMS_PREFIX"        : solution.EncryptionPrefix,

            "APP_VERSION_SOURCE": (
                    solution.AppFrameworks?seq_contains("expo") &&
                    solution.VersionSource == "AppFrameworks"
                )?then(
                    "manifest",
                    (
                        solution.VersionSource == "AppReference"
                    )?then(
                        "cmdb", ""
                    )
                )

        } +
        (solution.AppFrameworks?seq_contains("expo"))?then(
            {
                "EXPO_ID_OVERRIDE": (solution["AppFrameworks:expo"].IdOverride)!"",
                "RELEASE_CHANNEL": solution["AppFrameworks:expo"].ReleaseChannel,
                "OTA_ARTEFACT_BUCKET": occurrence.State.Attributes.OTA_ARTEFACT_BUCKET,
                "OTA_ARTEFACT_PREFIX": occurrence.State.Attributes.OTA_ARTEFACT_PREFIX,
                "OTA_ARTEFACT_URL": occurrence.State.Attributes.OTA_ARTEFACT_URL
            },
            {}
        ) +
        (solution.BuildFormats?seq_contains("ios"))?then(
            {
                "IOS_PROJECT_ROOT_DIR": solution["BuildFormats:ios"].ProjectRootDir,
                "IOS_DIST_BUNDLE_ID": (solution["BuildFormats:ios"].BundleIdOverride)!"",
                "IOS_DIST_DISPLAY_NAME": (solution["BuildFormats:ios"].DisplayNameOverride)!"",
                "IOS_DIST_NON_EXEMPT_ENCRYPTION": solution["BuildFormats:ios"].NonExemptEncryption,
                "IOS_DIST_APPLE_ID": (solution["BuildFormats:ios"].AppleTeamId)!"HamletFatal: Missing iOS Apple Team Id - solution.BuildFormats:ios.AppleTeamId",
                "IOS_DIST_EXPORT_METHOD": solution["BuildFormats:ios"].ExportMethod,
                "IOS_DIST_CODESIGN_IDENTITY": solution["BuildFormats:ios"].CodeSignIdentityPrefix,
                "IOS_DIST_P12_FILENAME": solution["BuildFormats:ios"].DistributionCertificateFileName,
                "IOS_DIST_P12_PASSWORD": (solution["BuildFormats:ios"].DistributionCertificatePassword)!"HamletFatal: Missing ios distribution certificate p12 password - solution.BuildFormats:ios.DistributionCertificatePassword",
                "IOS_DIST_PROVISIONING_PROFILE_FILENAME": solution["BuildFormats:ios"].ProvisioningProfileFileName
            } +
            (
                solution["BuildFormats:ios"].TestFlight.Enabled &&
                solution["BuildFormats:ios"].ExportMethod == "app-store"
            )?then(
                {
                    "IOS_DIST_APP_ID": (solution["BuildFormats:ios"].TestFlight.AppId)!"HamletFatal: Missing TestFlight App Id - solution.BuildFormats:ios.TestFlight.AppId",
                    "IOS_TESTFLIGHT_USERNAME": (solution["BuildFormats:ios"].TestFlight.Username)!"HamletFatal: Missing TestFlight username - solution.BuildFormats:ios.TestFlight.Username",
                    "IOS_TESTFLIGHT_PASSWORD": (solution["BuildFormats:ios"].TestFlight.Password)!"HamletFatal: Missing TestFlight password - solution.BuildFormats:ios.TestFlight.Password"
                },
                {}
            ),
            {}
        ) +
        (solution.BuildFormats?seq_contains("android"))?then(
            {
                "ANDROID_PROJECT_ROOT_DIR": solution["BuildFormats:android"].ProjectRootDir,
                "ANDROID_DIST_BUNDLE_ID": (solution["BuildFormats:android"].BundleIdOverride)!"",
                "ANDROID_DIST_KEYSTORE_FILENAME": solution["BuildFormats:android"].KeyStore.FileName,
                "ANDROID_DIST_KEYSTORE_PASSWORD": (solution["BuildFormats:android"].KeyStore.Password)!"HamletFatal: Missing android keystore password - solution.BuildFormats:android.KeyStore.Password",
                "ANDROID_DIST_KEY_ALIAS": solution["BuildFormats:android"].KeyStore.KeyAlias,
                "ANDROID_DIST_KEY_PASSWORD": (solution["BuildFormats:android"].KeyStore.KeyPassword)!"HamletFatal: Missing android key password - solution.BuildFormats:android.KeyStore.KeyPassword"
            } +
            (solution["BuildFormats:android"].PlayStore.Enabled)?then(
                {
                    "ANDROID_PLAYSTORE_JSON_KEY_FILENAME": solution["BuildFormats:ios"].PlayStore.JSONKeyFileName
                },
                {}
            ) +
            (solution["BuildFormats:android"].Firebase.Enabled)?then(
                {
                    "ANDROID_DIST_FIREBASE_APP_ID": (solution["BuildFormats:ios"].Firebase.AppId)!"HamletFatal: Missing firebase app Id - solution.BuildFormats:ios.Firebase.AppId",
                    "ANDROID_DIST_FIREBASE_JSON_KEY_FILENAME": solution["BuildFormats:ios"].Firebase.JSONKeyFileName
                },
                {}
            ),
            {}
        ) +
        (solution.Badge.Enabled)?then(
            {
                "ENVIRONMENT_BADGE_CONTENT": solution.Badge.Value,
                "ENVIRONMENT_BADGE_COLOR": solution.Badge.Color
            },
            {}
        )
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
                        getRegion(),
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
                    getRegion(),
                    operationsBucket,
                    configFilePath
                ) /]
    [/#if]
[/#macro]
