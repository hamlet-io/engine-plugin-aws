[#ftl]
[#macro aws_cdn_cf_deployment_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract subsets=["prologue", "template", "epilogue", "cli" ] /]
[/#macro]

[#macro aws_cdn_cf_deployment_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local resources = occurrence.State.Resources]
    [#local solution = occurrence.Configuration.Solution ]

    [#local cfId                = resources["cf"].Id]
    [#local cfName              = resources["cf"].Name]

    [#local wafPresent          = isPresent(solution.WAF) ]
    [#local wafVersion          = (solution.WAF.Version)!"v1" ]
    [#local wafAclId            = resources["wafacl"].Id]
    [#local wafAclArn           = resources["wafacl"].Arn]
    [#local wafAclLink          = resources["wafacl"][(wafVersion == "v1")?then("Id","Arn")]]
    [#local wafAclName          = resources["wafacl"].Name]

    [#local wafLogStreamingResources = resources["wafLogStreaming"]!{} ]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "OpsData" ])]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local operationsBucket = getExistingReference(baselineComponentIds["OpsData"]!"") ]

    [#local securityProfile = getSecurityProfile(occurrence, core.Type)]

    [#local certificateObject = getCertificateObject(solution.Certificate) ]
    [#local hostName = getHostName(certificateObject, occurrence) ]
    [#local certificateId = formatDomainCertificateId(certificateObject, hostName) ]
    [#local primaryDomainObject = getCertificatePrimaryDomain(certificateObject) ]
    [#local primaryFQDN = formatDomainName(hostName, primaryDomainObject)]

    [#-- Get alias list --]
    [#local aliases = [] ]
    [#list certificateObject.Domains as domain]
        [#local aliases += [ formatDomainName(hostName, domain.Name) ] ]
    [/#list]

    [#local origins = []]
    [#local cacheBehaviours = []]
    [#local defaultCacheBehaviour = []]
    [#local invalidationPaths = []]

    [#list occurrence.Occurrences![] as subOccurrence]
        [#local subCore = subOccurrence.Core ]
        [#local subSolution = subOccurrence.Configuration.Solution ]
        [#local subResources = subOccurrence.State.Resources ]

        [#local routeBehaviours = []]

        [#local originId = subResources["origin"].Id ]
        [#local originPathPattern = subResources["origin"].PathPattern ]
        [#local originDefaultPath = subResources["origin"].DefaultPath ]

        [#local behaviourPattern = originDefaultPath?then(
                                        "",
                                        originPathPattern
        )]

        [#if !subSolution.Enabled]
            [#continue]
        [/#if]

        [#local contextLinks = getLinkTargets(subOccurrence)]
        [#local _context =
            {
                "Environment" : {},
                "Links" : contextLinks,
                "BaselineLinks" : baselineLinks,
                "DefaultEnvironment" : defaultEnvironment(subOccurrence, contextLinks, baselineLinks),
                "DefaultCoreVariables" : false,
                "DefaultEnvironmentVariables" : false,
                "DefaultLinkVariables" : true,
                "DefaultBaselineVariables" : false,
                "Route" : subCore.SubComponent.Id
            }
        ]

        [#-- Add in entrance specifics including override of defaults --]
        [#local _context = invokeExtensions( subOccurrence, _context, occurrence )]

        [#local finalEnvironment = getFinalEnvironment(subOccurrence, _context ) ]
        [#local _context += finalEnvironment ]

        [#-- Get any event handlers --]
        [#local eventHandlerLinks = {} ]
        [#local eventHandlers = []]

        [#if subSolution.RedirectAliases.Enabled
                    && ( aliases?size > 1) ]

            [#local cfRedirectLink = {
                "cfredirect" : {
                    "Id" : "cfredirect",
                    "Name" : "cfredirect",
                    "Tier" : "gbl",
                    "Component" : "cfredirect",
                    "Version" : subSolution.RedirectAliases.RedirectVersion,
                    "Instance" : "",
                    "Function" : "cfredirect",
                    "Action" : "origin-request"
                }
            }]

            [#if getLinkTarget(occurrence, cfRedirectLink.cfredirect )?has_content ]
                [#local eventHandlerLinks += cfRedirectLink]

                [#local _context +=
                    {
                        "ForwardHeaders" : (_context.ForwardHeaders![]) + [
                            "Host"
                        ]
                    }]

                [#local _context +=
                    {
                        "CustomOriginHeaders" : (_context.CustomOriginHeaders![]) + [
                            getCFHTTPHeader(
                                "X-Redirect-Primary-Domain-Name",
                                primaryFQDN ),
                            getCFHTTPHeader(
                                "X-Redirect-Response-Code",
                                "301"
                            )
                        ]
                    }]
            [#else]
                [@fatal
                    message="Could not find cfredirect component"
                    context=cfRedirectLink
                /]
            [/#if]
        [/#if]

        [#local eventHandlerLinks += subSolution.EventHandlers ]
        [#list eventHandlerLinks?values as eventHandler]

            [#local eventHandlerTarget = getLinkTarget(occurrence, eventHandler) ]

            [@debug message="Event message handler" context=eventHandlerTarget enabled=false /]

            [#if !eventHandlerTarget?has_content]
                [#continue]
            [/#if]

            [#local eventHandlerCore = eventHandlerTarget.Core ]
            [#local eventHandlerResources = eventHandlerTarget.State.Resources ]
            [#local eventHandlerAttributes = eventHandlerTarget.State.Attributes ]
            [#local eventHandlerConfiguration = eventHandlerTarget.Configuration ]

            [#if (eventHandlerCore.Type) == LAMBDA_FUNCTION_COMPONENT_TYPE &&
                    eventHandlerAttributes["DEPLOYMENT_TYPE"] == "EDGE" ]

                    [#local eventHandlers += getCFEventHandler(
                                                eventHandler.Action,
                                                eventHandlerResources["version"].Id) ]
            [#else]
                [@fatal
                    description="Invalid Event Handler Component - Must be Lambda - EDGE"
                    context=occurrence
                /]
            [/#if]
        [/#list]

        [#local originLink = getLinkTarget(occurrence, subSolution.Origin.Link) ]

        [#if !originLink?has_content]
            [#continue]
        [/#if]

        [#local originLinkTargetCore = originLink.Core ]
        [#local originLinkTargetConfiguration = originLink.Configuration ]
        [#local originLinkTargetResources = originLink.State.Resources ]
        [#local originLinkTargetAttributes = originLink.State.Attributes ]

        [#switch originLinkTargetCore.Type]
            [#case MOBILEAPP_COMPONENT_TYPE ]
                [#local spaBaslineProfile = originLinkTargetConfiguration.Solution.Profiles.Baseline ]
                [#local spaBaselineLinks = getBaselineLinks(originLink, [ "CDNOriginKey" ])]
                [#local spaBaselineComponentIds = getBaselineComponentIds(spaBaselineLinks)]
                [#local cfAccess = getExistingReference(spaBaselineComponentIds["CDNOriginKey"]!"")]

                [#local originBucket = originLinkTargetAttributes["OTA_ARTEFACT_BUCKET"]]
                [#local originPrefix = originLinkTargetAttributes["OTA_ARTEFACT_PREFIX"]]

                [#local otaOrigin =
                    getCFS3Origin(
                        originId,
                        originBucket,
                        cfAccess,
                        originPrefix
                    )]
                [#local origins += otaOrigin ]

                [#local behaviour = getCFSPACacheBehaviour(
                    otaOrigin,
                    behaviourPattern,
                    {
                        "Default" : subSolution.CachingTTL.Default,
                        "Max" : subSolution.CachingTTL.Maximum,
                        "Min" : subSolution.CachingTTL.Minimum
                    },
                    subSolution.Compress,
                    eventHandlers,
                    _context.ForwardHeaders)]
                    [#local routeBehaviours += behaviour ]
                [#break]

            [#case S3_COMPONENT_TYPE ]

                [#local spaBaslineProfile = originLinkTargetConfiguration.Solution.Profiles.Baseline ]
                [#local spaBaselineLinks = getBaselineLinks(originLink, [ "CDNOriginKey" ])]
                [#local spaBaselineComponentIds = getBaselineComponentIds(spaBaselineLinks)]
                [#local cfAccess = getExistingReference(spaBaselineComponentIds["CDNOriginKey"]!"")]

                [#local originBucket = originLinkTargetAttributes["NAME"] ]

                [#local origin =
                    getCFS3Origin(
                        originId,
                        originBucket,
                        cfAccess,
                        subSolution.Origin.BasePath,
                        _context.CustomOriginHeaders)]
                [#local origins += origin ]

                [#local behaviour = getCFSPACacheBehaviour(
                    origin,
                    behaviourPattern,
                    {
                        "Default" : subSolution.CachingTTL.Default,
                        "Max" : subSolution.CachingTTL.Maximum,
                        "Min" : subSolution.CachingTTL.Minimum
                    },
                    subSolution.Compress,
                    eventHandlers,
                    _context.ForwardHeaders)]
                    [#local routeBehaviours += behaviour ]
                [#break]

            [#case SPA_COMPONENT_TYPE ]

                [#local spaBaslineProfile = originLinkTargetConfiguration.Solution.Profiles.Baseline ]
                [#local spaBaselineLinks = getBaselineLinks(originLink, [ "OpsData", "CDNOriginKey" ])]
                [#local spaBaselineComponentIds = getBaselineComponentIds(spaBaselineLinks)]
                [#local originBucket = getExistingReference(spaBaselineComponentIds["OpsData"]!"") ]
                [#local cfAccess = getExistingReference(spaBaselineComponentIds["CDNOriginKey"]!"")]

                [#local configPathPattern = originLinkTargetAttributes["CONFIG_PATH_PATTERN"]]

                [#local spaOrigin =
                    getCFS3Origin(
                        originId,
                        originBucket,
                        cfAccess,
                        formatAbsolutePath(getSettingsFilePrefix(originLink), "spa"),
                        _context.CustomOriginHeaders)]
                [#local origins += spaOrigin ]

                [#local configOrigin =
                    getCFS3Origin(
                        formatId(originId, "config"),
                        originBucket,
                        cfAccess,
                        formatAbsolutePath(getSettingsFilePrefix(originLink)),
                        _context.CustomOriginHeaders)]
                [#local origins += configOrigin ]

                [#local spaCacheBehaviour = getCFSPACacheBehaviour(
                    spaOrigin,
                    behaviourPattern,
                    {
                        "Default" : subSolution.CachingTTL.Default,
                        "Max" : subSolution.CachingTTL.Maximum,
                        "Min" : subSolution.CachingTTL.Minimum
                    },
                    subSolution.Compress,
                    eventHandlers,
                    _context.ForwardHeaders)]
                [#local routeBehaviours += spaCacheBehaviour ]

                [#local configCacheBehaviour = getCFSPACacheBehaviour(
                    configOrigin,
                    formatAbsolutePath( behaviourPattern, configPathPattern),
                    { "Default" : 60 },
                    subSolution.Compress,
                    eventHandlers,
                    _context.ForwardHeaders) ]

                [#local routeBehaviours += configCacheBehaviour ]
                [#break]

            [#case LB_COMPONENT_TYPE ]
            [#case LB_PORT_COMPONENT_TYPE ]

                [#switch originLinkTargetCore.Type ]
                    [#case LB_COMPONENT_TYPE ]
                        [#local originHostName = originLinkTargetAttributes["INTERNAL_FQDN"] ]
                        [#local originPath = formatAbsolutePath( "", subSolution.Origin.BasePath ) ]
                        [#local originProtocol = "HTTPS" ]
                        [#local originPort = 443 ]
                        [#break]

                    [#case LB_PORT_COMPONENT_TYPE ]
                        [#local originHostName = originLinkTargetAttributes["FQDN"] ]
                        [#local originPath = formatAbsolutePath( originLinkTargetAttributes["PATH"], subSolution.Origin.BasePath ) ]
                        [#local originProtocol = originLinkTargetAttributes["PROTOCOL"]]
                        [#local originPort = originLinkTargetAttributes["PORT"]]
                        [#break]
                [/#switch]

                [#local origin =
                            getCFHTTPOrigin(
                                originId,
                                originHostName,
                                _context.CustomOriginHeaders,
                                originPath,
                                originProtocol,
                                originPort,
                                subSolution.Origin.TLSProtocols,
                                subSolution.Origin.ConnectionTimeout
                            )]
                [#local origins += origin ]

                [#local behaviour =
                            getCFLBCacheBehaviour(
                                origin,
                                behaviourPattern,
                                subSolution.CachingTTL,
                                subSolution.Compress,
                                _context.ForwardHeaders,
                                eventHandlers )]
                [#local routeBehaviours += behaviour ]
                [#break]

            [#case APIGATEWAY_COMPONENT_TYPE ]
                [#local origin =
                            getCFHTTPOrigin(
                                originId,
                                originLinkTargetAttributes["FQDN"],
                                _context.CustomOriginHeaders,
                                formatAbsolutePath( originLinkTargetAttributes["BASE_PATH"], subSolution.Origin.BasePath )
                            )]
                [#local origins += origin ]

                [#local behaviour =
                            getCFLBCacheBehaviour(
                                origin,
                                behaviourPattern,
                                subSolution.CachingTTL,
                                subSolution.Compress,
                                _context.ForwardHeaders,
                                eventHandlers )]
                [#local routeBehaviours += behaviour ]
                [#break]

            [#case EXTERNALSERVICE_COMPONENT_TYPE ]

                [#local originHostName = originLinkTargetAttributes["FQDN"]!"HamletFatal: Could not find FQDN Attribute on external service" ]

                [#local path = originLinkTargetAttributes["PATH"]!"HamletFatal: Could not find PATH Attribute on external service" ]
                [#local originPath = formatAbsolutePath( path, subSolution.Origin.BasePath ) ]
                [#local protocol = (originLinkTargetAttributes["PROTOCOL"])!"https" ]
                [#local port = (originLinkTargetAttributes["PROTOCOL"])!443 ]

                [#local origin =
                            getCFHTTPOrigin(
                                originId,
                                originHostName,
                                _context.CustomOriginHeaders,
                                originPath,
                                protocol,
                                port,
                                subSolution.Origin.TLSProtocols,
                                subSolution.Origin.ConnectionTimeout
                            )]
                [#local origins += origin ]

                [#local behaviour =
                            getCFLBCacheBehaviour(
                                origin,
                                behaviourPattern,
                                subSolution.CachingTTL,
                                subSolution.Compress,
                                _context.ForwardHeaders,
                                eventHandlers )]
                [#local routeBehaviours += behaviour ]
                [#break]

        [/#switch]

        [#list routeBehaviours as behaviour ]
            [@debug message="behaviour check" context={ "Behaviour" : behaviour, "defaultPath" : originDefaultPath } enabled=true /]
            [#if (behaviour.PathPattern!"")?has_content  ]
                [#local cacheBehaviours += [ behaviour ] ]
            [#else]
                [#if ! defaultCacheBehaviour?has_content && originDefaultPath ]
                    [#local defaultCacheBehaviour = behaviour ]
                [#else]
                    [@fatal
                        message="Default route couldnt not be determined"
                        context=solution
                        detail="Check your routes to make sure PathPattern is different and that one has been defined"
                        enabled=false
                    /]
                [/#if]
            [/#if]
        [/#list]

        [#if subSolution.InvalidateOnUpdate ]
            [#if ! invalidationPaths?seq_contains("/*") ]
                [#local invalidationPaths += [ originPathPattern ]]
            [/#if]
        [/#if]
    [/#list]

    [#if deploymentSubsetRequired(CDN_COMPONENT_TYPE, true)]
        [#local restrictions = {} ]
        [#local whitelistedCountryCodes = getGroupCountryCodes(solution.CountryGroups![], false) ]
        [#if whitelistedCountryCodes?has_content]
            [#local restrictions = getCFGeoRestriction(whitelistedCountryCodes, false) ]
        [#else]
            [#local blacklistedCountryCodes = getGroupCountryCodes(solution.CountryGroups![], true) ]
            [#if blacklistedCountryCodes?has_content]
                [#local restrictions = getCFGeoRestriction(blacklistedCountryCodes, true) ]
            [/#if]
        [/#if]

        [#local errorResponses = []]
        [#if solution.Pages.NotFound?has_content || solution.Pages.Error?has_content ]
            [#local errorResponses +=
                getErrorResponse(
                        404,
                        200,
                        (solution.Pages.NotFound)?has_content?then(
                            solution.Pages.NotFound,
                            solution.Pages.Error
                        ))
            ]
        [/#if]

        [#if solution.Pages.Denied?has_content || solution.Pages.Error?has_content ]
            [#local errorResponses +=
                getErrorResponse(
                        403,
                        200,
                        (solution.Pages.Denied)?has_content?then(
                            solution.Pages.Denied,
                            solution.Pages.Error
                        ))
            ]
        [/#if]

        [#list solution.ErrorResponseOverrides as key,errorResponseOverride ]
            [#local errorResponses +=
                getErrorResponse(
                        errorResponseOverride.ErrorCode,
                        errorResponseOverride.ResponseCode,
                        errorResponseOverride.ResponsePagePath
                )
            ]
        [/#list]

        [@createCFDistribution
            id=cfId
            aliases=
                (isPresent(solution.Certificate))?then(
                    aliases,
                    []
                )
            cacheBehaviours=cacheBehaviours
            certificate=valueIfTrue(
                getCFCertificate(
                    certificateId,
                    securityProfile.HTTPSProfile,
                    solution.AssumeSNI),
                    isPresent(solution.Certificate)
                )
            comment=cfName
            customErrorResponses=errorResponses
            defaultCacheBehaviour=defaultCacheBehaviour
            defaultRootObject=solution.Pages.Root
            logging=valueIfTrue(
                getCFLogging(
                    operationsBucket,
                    formatComponentAbsoluteFullPath(
                        core.Tier,
                        core.Component,
                        occurrence
                    )
                ),
                solution.EnableLogging)
            origins=origins
            restrictions=valueIfContent(
                restrictions,
                restrictions)
            wafAclId=valueIfTrue(wafAclLink, wafPresent)
            tags=getOccurrenceCoreTags(occurrence,cfName)
        /]

    [/#if]

    [#if wafPresent ]
        [#if deploymentSubsetRequired(CDN_COMPONENT_TYPE, true)]
            [#if solution.WAF.Logging.Enabled]
                [#local wafFirehoseStreamId =
                    formatResourceId(AWS_KINESIS_FIREHOSE_STREAM_RESOURCE_TYPE, wafAclId)]

                [@setupLoggingFirehoseStream
                    occurrence=occurrence
                    componentSubset=CDN_COMPONENT_TYPE
                    resourceDetails=wafLogStreamingResources
                    destinationLink=baselineLinks["OpsData"]
                    bucketPrefix="WAF"
                    cloudwatchEnabled=true
                    cmkKeyId=kmsKeyId
                    version=solution.WAF.Version
                /]

                [@enableWAFLogging
                    wafaclId=wafAclId
                    wafaclArn=wafAclArn
                    deliveryStreamId=wafLogStreamingResources["stream"].Id
                    deliveryStreamArns=[ wafLogStreamingResources["stream"].Arn ]
                    regional=false
                    version=solution.WAF.Version
                /]
            [/#if]

            [@createWAFAclFromSecurityProfile
                id=wafAclId
                name=wafAclName
                metric=wafAclName
                wafSolution=solution.WAF
                securityProfile=securityProfile
                occurrence=occurrence
                version=solution.WAF.Version
            /]
        [/#if]
    [/#if]

    [#if deploymentSubsetRequired("epilogue", false)]
        [#if invalidationPaths?has_content && getExistingReference(cfId)?has_content && (wafVersion == "v1") ]
            [@addToDefaultBashScriptOutput
                [
                    "case $\{STACK_OPERATION} in",
                    "  create|update)"
                    "       # Invalidate distribution",
                    "       info \"Invalidating cloudfront distribution ... \"",
                    "       invalidate_distribution" +
                    "       \"" + getRegion() + "\" " +
                    "       \"" + getExistingReference(cfId) + "\" " +
                    "       \"" + invalidationPaths?join(" ") + "\" || return $?"
                    " ;;",
                    " esac"
                ]
            /]
        [/#if]
    [/#if]
[/#macro]
