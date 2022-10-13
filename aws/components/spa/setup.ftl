[#ftl]
[#macro aws_spa_cf_deployment_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract subsets=[] /]
    [@error
        message="Solution SPA Deprecation"
        context="Solution SPA has been replaced with the CDN component - please remove this unit from you solution level units"
    /]
[/#macro]

[#macro aws_spa_cf_deployment_generationcontract_application occurrence  ]
    [@addDefaultGenerationContract subsets=["pregeneration", "prologue", "config", "epilogue" ] /]
[/#macro]

[#macro aws_spa_cf_deployment_application occurrence  ]
    [@debug message="Entering" context=occurrence enabled=false /]

   [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local settings = occurrence.Configuration.Settings ]
    [#local resources = occurrence.State.Resources]
    [#local image = getOccurrenceImage(occurrence)]

    [#if (resources["legacyCF"]!{})?has_content ]
        [@fatal
            message="SPA Cloudfront distributions have been deprecated"
            detail="Please delete the solution SPA stack and add a CDN inbound link on the SPA"
            context=resources["legacyCF"]
        /]
    [/#if]

    [#local baselineLinks = getBaselineLinks(occurrence, [ "OpsData"] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]

    [#local operationsBucket = getExistingReference(baselineComponentIds["OpsData"]) ]

    [#local distributions = [] ]

    [#local contextLinks = getLinkTargets(occurrence) ]
    [#local _context =
        {
            "DefaultEnvironment" : defaultEnvironment(occurrence, contextLinks, baselineLinks),
            "Environment" : {},
            "Links" : contextLinks,
            "BaselineLinks" : baselineLinks,
            "DefaultCoreVariables" : false,
            "DefaultEnvironmentVariables" : false,
            "DefaultLinkVariables" : false,
            "DefaultBaselineVariables" : false
        }
    ]

    [#-- Add in extension specifics including override of defaults --]
    [#local _context = invokeExtensions( occurrence, _context )]

    [#local _context += getFinalEnvironment(occurrence, _context) ]

    [#list _context.Links as id,linkTarget ]

        [#local linkTargetCore = linkTarget.Core ]
        [#local linkTargetConfiguration = linkTarget.Configuration ]
        [#local linkTargetResources = linkTarget.State.Resources ]
        [#local linkTargetAttributes = linkTarget.State.Attributes ]
        [#local linkDirection = linkTarget.Direction ]

        [#switch linkTargetCore.Type]
            [#case CDN_ROUTE_COMPONENT_TYPE ]
                [#if linkDirection == "inbound" ]
                    [#local distributions += [ {
                        "DistributionId" : linkTargetAttributes["DISTRIBUTION_ID"],
                        "PathPattern" : linkTargetResources["behaviour"].PathPattern
                    }]]
                [/#if]
                [#break]
        [/#switch]
    [/#list]

    [#if (! distributions?has_content) && deploymentSubsetRequired("epilogue", false) ]
        [@fatal
            message="An SPA must have at least 1 CDN Route component link - Add an inbound CDN Route link to the SPA"
            context=solution
            enabled=true
        /]
    [/#if]

    [#if deploymentSubsetRequired("config", false)]
        [@addToDefaultJsonOutput
            content={ "RUN_ID" : getCLORunId() } + _context.Environment
        /]
    [/#if]

    [#if deploymentSubsetRequired("pregeneration", false) && image.Source == "url" ]
        [@addToDefaultBashScriptOutput
            content=getAWSImageFromUrlScript(image, true)
        /]
    [/#if]

    [#if deploymentSubsetRequired("prologue", false)]

        [@addToDefaultBashScriptOutput
            content=
                getAWSImageBuildScript(
                    "spaFiles",
                    getRegion(),
                    image
                ) +
                syncFilesToBucketScript(
                    "spaFiles",
                    getRegion(),
                    operationsBucket,
                    formatRelativePath(
                        getOccurrenceSettingValue(occurrence, "SETTINGS_PREFIX"),
                        "spa"
                    )
                ) +
                getLocalFileScript(
                    "configFiles",
                    "$\{CONFIG}",
                    "config.json"
                ) +
                [#-- Ensure config.json is not cached for too long --]
                [#-- as it can contain version ids that need to be --]
                [#-- refetched when the code changes.              --]
                [#-- Otherwise it is not obvious that new code has --]
                [#-- been loaded becuase the version info doesn't  --]
                [#-- change.                                       --]
                syncFilesToBucketScript(
                    "configFiles",
                    getRegion(),
                    operationsBucket,
                    formatRelativePath(
                        getOccurrenceSettingValue(occurrence, "SETTINGS_PREFIX"),
                        solution.ConfigPath
                    ),
                    true,
                    [],
                    60
                ) /]
    [/#if]

    [#if solution.InvalidateOnUpdate && distributions?has_content ]
        [#local invalidationScript = []]
        [#list distributions as distribution ]
            [#local distributionId = distribution.DistributionId ]
            [#local pathPattern = distribution.PathPattern]

            [#local invalidationScript += [
                "       # Invalidate distribution",
                "       info \"Invalidating cloudfront distribution " + distributionId + " " + pathPattern + "\"",
                "       invalidate_distribution" +
                "       \"" + getRegion() + "\" " +
                "       \"" + distributionId + "\" " +
                "       \"" + pathPattern + "\" || return $?"
            ]]
        [/#list]

        [#if deploymentSubsetRequired("epilogue", false)]
            [@addToDefaultBashScriptOutput
                [
                    "case $\{STACK_OPERATION} in",
                    "  create|update)"
                ] +
                invalidationScript +
                [
                    " ;;",
                    " esac"
                ]
            /]
        [/#if]
    [/#if]
[/#macro]
