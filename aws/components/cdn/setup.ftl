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
    [#local wafAclId            = resources["wafacl"].Id]
    [#local wafAclArn           = resources["wafacl"].Arn]
    [#local wafAclLink          = resources["wafacl"].Arn]
    [#local wafAclName          = resources["wafacl"].Name]

    [#local wafLogStreamingResources = resources["wafLogStreaming"]!{} ]

    [#local defaultCachePolicyRequired = false ]
    [#local defaultCachePolicy = resources["cachePolicyDefault"]]

    [#local defaultRequestForwardPolicyRequired = false ]
    [#local defaultRequestForwardPolicy = resources["requestPolicyDefault"] ]

    [#local originPlaceHolder = resources["originPlaceHolder"]]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "OpsData" ])]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local operationsBucket = getExistingReference(baselineComponentIds["OpsData"]!"") ]

    [#local securityProfile = getSecurityProfile(occurrence, core.Type)]
    [#local loggingProfile = getLoggingProfile(occurrence)]

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

    [#local defaultTTLPolicy = {}]

    [#list (occurrence.Occurrences![])?filter(
            x -> x.Configuration.Solution.Enabled && x.Core.Type == CDN_ORIGIN_COMPONENT_TYPE) as subOccurrence]

        [#local subCore = subOccurrence.Core ]
        [#local subSolution = subOccurrence.Configuration.Solution ]
        [#local subResources = subOccurrence.State.Resources ]

        [#local origin = subResources["origin"]]

        [#local originRequestPolicy = subResources["originRequestPolicy"]]

        [#local originLink = getLinkTarget(occurrence, subSolution.OriginLink) ]

        [#if !originLink?has_content]
            [#continue]
        [/#if]

        [#local customHeaders = []]
        [#list subSolution.RequestForwarding.AdditionalHeaders as id, header ]
            [#local customHeaders = combineEntities(
                customHeaders,
                [
                    {
                        "HeaderName": (header.Name)!id,
                        "HeaderValue": header.Value
                    }
                ]
            )]
        [/#list]

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
                "CustomHeadersConfig" : customHeaders
            }
        ]

        [#-- Add in entrance specifics including override of defaults --]
        [#local _context = invokeExtensions( subOccurrence, _context, occurrence )]

        [#local originLinkTargetCore = originLink.Core ]
        [#local originLinkTargetConfiguration = originLink.Configuration ]
        [#local originLinkTargetResources = originLink.State.Resources ]
        [#local originLinkTargetAttributes = originLink.State.Attributes ]

        [@createCFOriginRequestPolicy?with_args(
            getOriginRequestPolicy(
                "originRequestPolicy",
                subSolution.RequestForwarding.Policy,
                originLinkTargetCore.Type,
                subSolution.RequestForwarding["Policy:Custom"].Methods,
                subSolution.RequestForwarding["Policy:Custom"].Cookies,
                combineEntities(
                    _context.ForwardHeaders![],
                    subSolution.RequestForwarding["Policy:Custom"].Headers,
                    UNIQUE_COMBINE_BEHAVIOUR
                ),
                subSolution.RequestForwarding["Policy:Custom"].QueryParams
            )
        ) id=originRequestPolicy.Id name=originRequestPolicy.Name /]

        [#if ! origins?map(x -> x.Id )?seq_contains(origin.Id ) ]
            [#local origins = combineEntities(
                    origins,
                    getOriginFromLink(
                        origin.Id,
                        subSolution.BasePath,
                        _context.CustomHeadersConfig,
                        originLink,
                        subSolution.TLSProtocols,
                        subSolution.ConnectionTimeout
                    ),
                    APPEND_COMBINE_BEHAVIOUR
                )]
        [/#if]

    [/#list]

    [#list (occurrence.Occurrences![])?filter(
            x -> x.Configuration.Solution.Enabled && x.Core.Type == CDN_RESPONSE_POLICY_COMPONENT_TYPE) as subOccurrence]

        [#local subCore = subOccurrence.Core ]
        [#local subSolution = subOccurrence.Configuration.Solution ]
        [#local subResources = subOccurrence.State.Resources ]

        [#local responseHeaderPolicy = subResources.responseHeaderPolicy]

        [@createCFResponseHeadersPolicy
            id=responseHeaderPolicy.Id
            name=responseHeaderPolicy.Name
            corsEnabled=subSolution.HeaderInjection.CORS.Enabled
            corsOverride=( ! subSolution.HeaderInjection.CORS.PreferOrigin )
            corsPolicy=subSolution.HeaderInjection.CORS
            securityHeadersEnabled=subSolution.HeaderInjection.Security.Enabled
            securityHeadersOverride=( ! subSolution.HeaderInjection.Security.PreferOrigin )
            securityHeadersPolicy=subSolution.HeaderInjection.Security
            strictTransportSecurityEnabled=subSolution.HeaderInjection.StrictTransportSecurity.Enabled
            strictTransportSecurityPolicy=subSolution.HeaderInjection.StrictTransportSecurity
            strictTransportSecurityOverride=( ! subSolution.HeaderInjection.StrictTransportSecurity.PreferOrigin )
            customHeaders=subSolution.HeaderInjection.Additional
        /]
    [/#list]

    [#list (occurrence.Occurrences![])?filter(
            x -> x.Configuration.Solution.Enabled && x.Core.Type == CDN_CACHE_POLICY_COMPONENT_TYPE) as subOccurrence]

        [#local subCore = subOccurrence.Core ]
        [#local subSolution = subOccurrence.Configuration.Solution ]
        [#local subResources = subOccurrence.State.Resources ]

        [#local cachePolicy = subResources["cachepolicy"]]
        [@createCFCachePolicy
            id=cachePolicy.Id
            name=cachePolicy.Name
            ttl={
                "Default" : subSolution.TTL.Default,
                "Max" : subSolution.TTL.Maximum,
                "Min" : subSolution.TTL.Minimum
            }
            cookieNames=subSolution.Cookies
            headerNames=subSolution.Headers
            queryStringNames=subSolution.QueryParams
            compressionProtocols=subSolution.CompressionEncoding
        /]

    [/#list]

    [#list (occurrence.Occurrences![])?filter(
            x -> x.Configuration.Solution.Enabled && x.Core.Type == CDN_ROUTE_COMPONENT_TYPE)  as subOccurrence]

        [#local subCore = subOccurrence.Core ]
        [#local subSolution = subOccurrence.Configuration.Solution ]
        [#local subResources = subOccurrence.State.Resources ]

        [#local routeBehaviours = []]
        [#local customHeaders = []]
        [#local allowedHttpMethods = ["GET", "HEAD", "OPTIONS"]]

        [#local behaviourResource = subResources["behaviour"]]
        [#local originRequestPolicyRequired = true]

        [#-- Pick the source of the Origin --]
        [#switch subSolution.OriginSource]
            [#case "Route"]
                [#local origin = subResources["origin"]]
                [#local originConfig = subSolution["OriginSource:Route"]]
                [#local originRequestPolicy = subResources["originRequestPolicy"]]

                [#list originConfig.RequestForwarding.AdditionalHeaders as id, header ]
                    [#local customHeaders = combineEntities(
                        customHeaders,
                        [
                            {
                                "HeaderName": (header.Name)!id,
                                "HeaderValue": header.Value
                            }
                        ]
                    )]
                [/#list]
                [#break]

            [#case "CDN"]
                [#local originLink = getLinkTarget(
                    subOccurrence,
                    {
                        "Tier" : subOccurrence.Core.Tier.Id,
                        "Component": subOccurrence.Core.Component.RawId,
                        "SubComponent": subSolution["OriginSource:CDN"].Id,
                        "Instance": subSolution["OriginSource:CDN"].Instance,
                        "Version": subSolution["OriginSource:CDN"].Version,
                        "Type" : CDN_ORIGIN_COMPONENT_TYPE
                    },
                    false
                )]
                [#if ! originLink?has_content]
                    [#continue]
                [/#if]
                [#local origin = originLink.State.Resources.origin]
                [#local originConfig = originLink.Configuration.Solution ]
                [#local originRequestPolicy = originLink.State.Resources.originRequestPolicy]
                [#break]

            [#case "Placeholder"]
                [#if ! origins?map(x -> x.Id)?seq_contains(originPlaceHolder.Id)]
                    [#local origins = combineEntities(
                            origins,
                            getCFHTTPOrigin(
                                originPlaceHolder.Id,
                                "example.org"
                            ),
                            APPEND_COMBINE_BEHAVIOUR
                    )]
                [/#if]

                [#local origin = originPlaceHolder ]
                [#local originConfig = {}]
                [#local originRequestPolicyRequired = false]
                [#local originRequestPolicy = {
                    "Id" : "",
                    "Name" : ""
                }]

        [/#switch]

        [#if behaviourResource.DefaultPath ]
            [#local defaultTTLPolicy = {
                "Max": subSolution.CachingTTL.Maximum,
                "Min": subSolution.CachingTTL.Minimum,
                "Default" : subSolution.CachingTTL.Default
            }]
        [#else]
            [#if subSolution.CachingTTL.Configured]
                [@fatal
                    message="Caching TTL control moved to custom Cache Policy"
                    detail="To add caching ttl control to a non default route you will need to create a custom CachePolicy"
                    context={
                        "cdn" : occurrence.Core.RawId,
                        "Route" : subOccurrence.Core.RawId,
                        "TTLConfig" : subSolution.CachingTTL
                    }
                /]
            [/#if]
        [/#if]

        [#-- Pick the Cache Policy to use --]
        [#switch subSolution.CachePolicy]
            [#case "Default"]
                [#local defaultCachePolicyRequired = true]
                [#local cachePolicy = defaultCachePolicy]
                [#local cacheHttpMethods = ["GET", "HEAD"]]
                [#break]

            [#case "Custom"]
                [#local cachePolicyLink = getLinkTarget(
                    subOccurrence,
                    {
                        "Tier" : subOccurrence.Core.Tier.Id,
                        "Component" : subOccurrence.Core.Component.RawId,
                        "SubComponent" : subSolution["CachePolicy:Custom"].Id,
                        "Instance" : subSolution["CachePolicy:Custom"].Instance,
                        "Version": subSolution["CachePolicy:Custom"].Version,
                        "Type" : CDN_CACHE_POLICY_COMPONENT_TYPE
                    },
                    false
                )]

                [#if !cachePolicyLink?has_content ]
                    [#continue]
                [/#if]

                [#local cachePolicy = (cachePolicyLink.State.Resources.cachepolicy)!{}]
                [#local cacheHttpMethods = cachePolicyLink.Configuration.Solution.Methods]
                [#break]
        [/#switch]

        [#local behaviourPattern = behaviourResource.DefaultPath?then(
                                        "",
                                        behaviourResource.PathPattern
        )]

        [#-- Response Policy --]
        [#if (subSolution.ResponsePolicy.Id)??]
            [#local responsePolicyLink = getLinkTarget(
                subOccurrence,
                {
                    "Tier" : subOccurrence.Core.Tier.Id,
                    "Component" : subOccurrence.Core.Component.RawId,
                    "SubComponent" : subSolution.ResponsePolicy.Id,
                    "Instance" : subSolution.ResponsePolicy.Instance,
                    "Version": subSolution.ResponsePolicy.Version,
                    "Type" : CDN_RESPONSE_POLICY_COMPONENT_TYPE
                },
                false
            )]

            [#if ! responsePolicyLink?has_content ]
                [#continue]
            [/#if]

            [#local responseHeadersPolicy = responsePolicyLink.State.Resources.responseHeaderPolicy]
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
                "Route" : subCore.SubComponent.Id,
                "CustomHeadersConfig" : customHeaders,
                "ForwardHeaders" : (originConfig.Headers)![]
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
                    "Enabled" : true,
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
                        "CustomHeadersConfig" :
                            (_context.CustomHeadersConfig![]) +
                            [
                                getCFHTTPHeader(
                                    "X-Redirect-Primary-Domain-Name",
                                    primaryFQDN ),
                                getCFHTTPHeader(
                                    "X-Redirect-Response-Code",
                                    "301"
                                )
                            ]
                    } ]
            [#else]
                [@fatal
                    message="Could not find cfredirect component"
                    context=cfRedirectLink
                /]
            [/#if]
        [/#if]

        [#local eventHandlerLinks += subSolution.EventHandlers ]
        [#list eventHandlerLinks?values?filter(x -> x.Enabled) as eventHandler]

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

        [#if originConfig?has_content ]
            [#local originLink = getLinkTarget(occurrence, originConfig.OriginLink) ]
            [#if !originLink?has_content]
                [#continue]
            [/#if]

            [#local originLinkTargetCore = originLink.Core ]
            [#local originLinkTargetConfiguration = originLink.Configuration ]
            [#local originLinkTargetResources = originLink.State.Resources ]
            [#local originLinkTargetAttributes = originLink.State.Attributes ]

            [#local allowedHttpMethods = getOriginRequestPolicy(
                "behaviour",
                originConfig.RequestForwarding.Policy,
                originLinkTargetCore.Type,
                originConfig.RequestForwarding["Policy:Custom"].Methods
            ).httpMethods]

            [#if originRequestPolicyRequired]
                [@createCFOriginRequestPolicy?with_args(
                    getOriginRequestPolicy(
                        "originRequestPolicy",
                        originConfig.RequestForwarding.Policy,
                        originLinkTargetCore.Type,
                        originConfig.RequestForwarding["Policy:Custom"].Methods,
                        originConfig.RequestForwarding["Policy:Custom"].Cookies,
                        _context.ForwardHeaders![],
                        originConfig.RequestForwarding["Policy:Custom"].QueryParams
                    )
                ) id=originRequestPolicy.Id name=originRequestPolicy.Name /]
            [/#if]

            [#if ! origins?map(x -> x.Id )?seq_contains(origin.Id )]
                [#local origins = combineEntities(
                        origins,
                        getOriginFromLink(
                            origin.Id,
                            originConfig.BasePath,
                            _context.CustomHeadersConfig,
                            originLink,
                            originConfig.TLSProtocols,
                            originConfig.ConnectionTimeout
                        ),
                        APPEND_COMBINE_BEHAVIOUR
                    )]
            [/#if]

            [#switch originLinkTargetCore.Type]
                [#case MOBILEAPP_COMPONENT_TYPE ]
                    [#local behaviour = getCFCacheBehaviour(
                            origins?filter( x -> x.Id == origin.Id)[0],
                            cachePolicy.Id,
                            behaviourPattern,
                            allowedHttpMethods,
                            cacheHttpMethods,
                            subSolution.Compress,
                            eventHandlers,
                            originRequestPolicy.Id,
                            (responseHeadersPolicy.Id)!""
                        )]
                        [#local routeBehaviours += [{ "Priority" : subSolution.Priority, "behaviour": behaviour }]]
                    [#break]

                [#case S3_COMPONENT_TYPE ]

                    [#local behaviour = getCFCacheBehaviour(
                        origins?filter( x -> x.Id == origin.Id)[0],
                        cachePolicy.Id,
                        behaviourPattern,
                        allowedHttpMethods,
                        cacheHttpMethods,
                        subSolution.Compress,
                        eventHandlers,
                        originRequestPolicy.Id,
                        (responseHeadersPolicy.Id)!""
                    )]
                    [#local routeBehaviours += [{ "Priority" : subSolution.Priority, "behaviour": behaviour }]]
                    [#break]

                [#case SPA_COMPONENT_TYPE ]

                    [#local configPathPattern = originLinkTargetAttributes["CONFIG_PATH_PATTERN"]]

                    [#local behaviour = getCFCacheBehaviour(
                        origins?filter( x -> x.Id == origin.Id)[0],
                        cachePolicy.Id,
                        behaviourPattern,
                        allowedHttpMethods,
                        cacheHttpMethods,
                        subSolution.Compress,
                        eventHandlers,
                        originRequestPolicy.Id,
                        (responseHeadersPolicy.Id)!""
                    )]
                    [#local routeBehaviours += [{ "Priority" : subSolution.Priority, "behaviour": behaviour }]]

                    [#local configBehaviour = getCFCacheBehaviour(
                        origins?filter( x -> x.Id == formatId(origin.Id, "config"))[0],
                        cachePolicy.Id,
                        formatAbsolutePath( behaviourPattern, configPathPattern),
                        allowedHttpMethods,
                        cacheHttpMethods,
                        subSolution.Compress,
                        eventHandlers,
                        originRequestPolicy.Id,
                        (responseHeadersPolicy.Id)!""
                    )]

                    [#local routeBehaviours += [{ "Priority" : subSolution.Priority, "behaviour": configBehaviour }]]
                    [#break]

                [#case LB_COMPONENT_TYPE ]
                [#case LB_PORT_COMPONENT_TYPE ]
                    [#local behaviour = getCFCacheBehaviour(
                        origins?filter( x -> x.Id == origin.Id)[0],
                        cachePolicy.Id,
                        behaviourPattern,
                        allowedHttpMethods,
                        cacheHttpMethods,
                        subSolution.Compress,
                        eventHandlers,
                        originRequestPolicy.Id,
                        (responseHeadersPolicy.Id)!""
                    )]
                    [#local routeBehaviours += [{ "Priority" : subSolution.Priority, "behaviour": behaviour }]]
                    [#break]

                [#case APIGATEWAY_COMPONENT_TYPE ]
                    [#local behaviour = getCFCacheBehaviour(
                        origins?filter( x -> x.Id == origin.Id)[0],
                        cachePolicy.Id,
                        behaviourPattern,
                        allowedHttpMethods,
                        cacheHttpMethods,
                        subSolution.Compress,
                        eventHandlers,
                        originRequestPolicy.Id,
                        (responseHeadersPolicy.Id)!""
                    )]
                    [#local routeBehaviours += [{ "Priority" : subSolution.Priority, "behaviour": behaviour }]]
                    [#break]

                [#case EXTERNALSERVICE_COMPONENT_TYPE ]
                    [#local behaviour = getCFCacheBehaviour(
                        origins?filter( x -> x.Id == origin.Id)[0],
                        cachePolicy.Id,
                        behaviourPattern,
                        allowedHttpMethods,
                        cacheHttpMethods,
                        subSolution.Compress,
                        eventHandlers,
                        originRequestPolicy.Id,
                        (responseHeadersPolicy.Id)!""
                    )]
                    [#local routeBehaviours += [{ "Priority" : subSolution.Priority, "behaviour": behaviour }]]
                    [#break]

            [/#switch]
        [/#if]

        [#if subSolution.OriginSource == "Placeholder" ]
            [#local defaultRequestForwardPolicyRequired = true]
            [#local behaviour = getCFCacheBehaviour(
                origins?filter( x -> x.Id == origin.Id)[0],
                cachePolicy.Id,
                behaviourPattern,
                allowedHttpMethods,
                cacheHttpMethods,
                subSolution.Compress,
                eventHandlers,
                defaultRequestForwardPolicy.Id,
                (responseHeadersPolicy.Id)!""
            )]
            [#local routeBehaviours += [{ "Priority" : subSolution.Priority, "behaviour": behaviour }]]
        [/#if]

        [#-- Sort the routes to ensure they are mapped to their precedence --]
        [#local routeBehaviours = asFlattenedArray(routeBehaviours?sort_by("Priority")?map( x -> x.behaviour))]

        [#list routeBehaviours as behaviour ]
            [@debug message="behaviour check" context={ "Behaviour" : behaviour, "defaultPath" : behaviourResource.DefaultPath } enabled=true /]
            [#if (behaviour.PathPattern!"")?has_content  ]
                [#local cacheBehaviours += [ behaviour ] ]
            [#else]
                [#if ! defaultCacheBehaviour?has_content && behaviourResource.DefaultPath ]
                    [#local defaultCacheBehaviour = behaviour ]
                [#else]
                    [@fatal
                        message="Default route could not not be determined"
                        context=solution
                        detail="Check your routes to make sure PathPatterns are different and that a default path pattern is set with _default"
                        enabled=false
                    /]
                [/#if]
            [/#if]
        [/#list]

        [#if subSolution.InvalidateOnUpdate ]
            [#if ! invalidationPaths?seq_contains('/*') ]
                [#local invalidationPaths += [ behaviourResource.PathPattern ]]
            [/#if]
        [/#if]
    [/#list]

    [#if deploymentSubsetRequired(CDN_COMPONENT_TYPE, true)]

        [#if defaultCachePolicyRequired ]
            [@createCFCachePolicy
                id=defaultCachePolicy.Id
                name=defaultCachePolicy.Name
                ttl=defaultTTLPolicy
                headerNames=_context.ForwardHeaders
                cookieNames=["_all"]
                queryStringNames=["_all"]
                compressionProtocols=["gzip", "brotli"]
            /]
        [/#if]

        [#if defaultRequestForwardPolicyRequired]
            [@createCFOriginRequestPolicy
                id=defaultRequestForwardPolicy.Id
                name=defaultRequestForwardPolicy.Name
                headerNames=[
                    "_cdn",
                    [#-- Include the extra CloudFront headers available from CloudFront --]
                    "CloudFront-Viewer-Address",
                    "CloudFront-Viewer-Country",
                    "CloudFront-Viewer-City",
                    "CloudFront-Viewer-Country-Name",
                    "CloudFront-Viewer-Country-Region",
                    "CloudFront-Viewer-Country-Region-Name",
                    "CloudFront-Forwarded-Proto",
                    "CloudFront-Viewer-Http-Version",
                    "CloudFront-Viewer-TLS"
                ]
                cookieNames=["_all"]
                queryStringNames=["_all"]
            /]
        [/#if]

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
            [#if errorResponseOverride.Enabled]
                [#local errorResponses +=
                    getErrorResponse(
                            errorResponseOverride.ErrorCode,
                            errorResponseOverride.ResponseCode,
                            errorResponseOverride.ResponsePagePath
                    )
                ]
            [/#if]
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
            tags=getOccurrenceTags(occurrence)
        /]

    [/#if]

    [#if wafPresent ]
        [#if solution.WAF.Logging.Enabled]

            [#if getRegion() != "us-east-1" ]
                [@fatal
                    message="To enable firehose based logging for WAF on CDN the deployment must be run from us-east-1"
                    context={
                        "CDNId" : occurrence.Core.Id,
                        "Region" : getRegion()
                    }
                /]
            [/#if]

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
                loggingProfile=loggingProfile
            /]

            [@enableWAFLogging
                wafaclId=wafAclId
                wafaclArn=wafAclArn
                componentSubset=CDN_COMPONENT_TYPE
                deliveryStreamId=wafLogStreamingResources["stream"].Id
                deliveryStreamArns=[ wafLogStreamingResources["stream"].Arn ]
                regional=false
            /]
        [/#if]


        [#if deploymentSubsetRequired(CDN_COMPONENT_TYPE, true)]
            [@createWAFAclFromSecurityProfile
                id=wafAclId
                name=wafAclName
                metric=wafAclName
                wafSolution=solution.WAF
                securityProfile=securityProfile
                occurrence=occurrence
            /]
        [/#if]
    [/#if]

    [#if deploymentSubsetRequired("epilogue", false)]
        [#if invalidationPaths?has_content && getExistingReference(cfId)?has_content ]
            [@addToDefaultBashScriptOutput
                [
                    r'case ${STACK_OPERATION} in',
                    r'  create|update)',
                    r'       cf_id="$(get_cloudformation_stack_output "' + getRegion() + r'" "${STACK_NAME}" "' + cfId + r'" "ref" || return $?)"',
                    r'       # Invalidate distribution',
                    r'       info "Invalidating cloudfront distribution"',
                    r'       invalidate_distribution "' + getRegion() + r'" "${cf_id}" "' + invalidationPaths?join(" ") + r'" || return $?',
                    r' ;;',
                    r' esac'
                ]
            /]
        [/#if]
    [/#if]
[/#macro]
