[#ftl]

[#assign CF_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        DNS_ATTRIBUTE_TYPE : {
            "Attribute" : "DomainName"
        }
    }
]

[#assign CF_ACCESS_ID_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        CANONICAL_ID_ATTRIBUTE_TYPE : {
            "Attribute" : "S3CanonicalUserId"
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_CLOUDFRONT_DISTRIBUTION_RESOURCE_TYPE
    mappings=CF_OUTPUT_MAPPINGS
/]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_CLOUDFRONT_ACCESS_ID_RESOURCE_TYPE
    mappings=CF_ACCESS_ID_OUTPUT_MAPPINGS
/]

[#function getCFHTTPHeader name value]
    [#return
        {
          "HeaderName" : name,
          "HeaderValue" : value
        }
    ]
[/#function]

[#function getCFOriginPath path ]
    [#return path?ensure_starts_with("/")?remove_ending("/") ]
[/#function]

[#function getCFBehaviourPath path ]
    [#if path?has_content ]
        [#local path = path?ensure_starts_with("/") ]
        [#if path?ends_with("/") && path != "/" ]
            [#local path += "*" ]
        [/#if]
    [/#if]
    [#return path ]
[/#function]

[#function getCFS3Origin id bucket
            accessId
            path=""
            headers=[]]
    [#return
        [
            {
                "DomainName" : bucket + ".s3.amazonaws.com",
                "Id" : id,
                "S3OriginConfig" : {
                    "OriginAccessIdentity" : "origin-access-identity/cloudfront/" + accessId
                }
            } +
            attributeIfContent("OriginCustomHeaders", asArray(headers)) +
            attributeIfContent("OriginPath", getCFOriginPath(path) )
        ]
    ]
[/#function]

[#function getCFHTTPOrigin id domain
        headers=[]
        path=""
        protocol="HTTPS"
        port=443
        tlsProtocols=["TLSv1.2"]
        originTimeout=""]
    [#return
        [
            {
                "DomainName" : domain,
                "Id" : id,
                "CustomOriginConfig" : {} +
                    (protocol?lower_case == "https")?then(
                        {
                            "OriginProtocolPolicy" : "https-only",
                            "HTTPSPort" : port?number,
                            "OriginSSLProtocols" : asArray(tlsProtocols)
                        },
                        {}
                    ) +
                    (protocol?lower_case == "http" )?then(
                        {
                            "OriginProtocolPolicy" : "http-only",
                            "HTTPPort" : port?number
                        },
                        {}
                    ) +
                    attributeIfContent(
                        "OriginReadTimeout",
                        originTimeout
                    )
            } +
            attributeIfContent("OriginCustomHeaders", asArray(headers)) +
            attributeIfContent("OriginPath", getCFOriginPath(path))
        ]
    ]
[/#function]

[#function getCFEventHandler type lambdaVersionId ]
    [#return
        [
          {
              "EventType" : type,
              "LambdaFunctionARN" : getArn(lambdaVersionId, false, "us-east-1")
          }
        ]
    ]
[/#function]

[#function getCFCacheBehaviour
    origin
    cachePolicyId
    path=""
    allowedMethods=[]
    cachedMethods=[]
    compress=false
    eventHandlers=[]
    originRequestPolicyId="",
    responseHeadersPolicyId="",
    viewerProtocolPolicy="redirect-to-https"
    smoothStreaming=false
    trustedSigners=[]
]
    [#return
        [
            {
                "Compress" : compress,
                "SmoothStreaming" : smoothStreaming,
                "TargetOriginId" : asString(origin, "Id"),
                "ViewerProtocolPolicy" : viewerProtocolPolicy,
                "CachePolicyId": getReference(cachePolicyId)
            } +
            attributeIfContent("PathPattern", path ) +
            attributeIfContent("AllowedMethods", allowedMethods, asArray(allowedMethods)) +
            attributeIfContent("CachedMethods", cachedMethods, asArray(cachedMethods)) +
            attributeIfContent("TrustedSigners", trustedSigners) +
            attributeIfContent("LambdaFunctionAssociations", eventHandlers) +
            attributeIfContent("OriginRequestPolicyId", originRequestPolicyId, getReference(originRequestPolicyId)) +
            attributeIfContent("ResponseHeadersPolicyId", responseHeadersPolicyId, getReference(responseHeadersPolicyId))
        ]
    ]
[/#function]

[#function getCFLogging bucket prefix="" includeCookies=false]
    [#return
        {
            "Bucket" : bucket + ".s3.amazonaws.com",
            "IncludeCookies" : includeCookies,
            "Prefix" :
                formatRelativePath("CLOUDFRONTLogs", prefix)
        }
    ]
[/#function]

[#function getCFCertificate id httpsProtocolPolicy assumeSNI=true ]
    [#local acmCertificateArn = getExistingReference(id, ARN_ATTRIBUTE_TYPE, "us-east-1") ]
    [#return
        {
            "AcmCertificateArn" :
                acmCertificateArn?has_content?then(
                    acmCertificateArn,
                    formatRegionalArn(
                        "acm",
                        formatTypedArnResource(
                            "certificate",
                            id,
                            "/"
                        ),
                        "us-east-1"
                    )
                ),
            "MinimumProtocolVersion" : httpsProtocolPolicy,
            "SslSupportMethod" : assumeSNI?then("sni-only", "vip")
        }
    ]
[/#function]

[#function getCFGeoRestriction locations blacklist=false]
    [#return
        valueIfContent(
            {
                "GeoRestriction" : {
                    "Locations" :
                        asArray(locations![]),
                    "RestrictionType" :
                        blacklist?then(
                            "blacklist",
                            "whitelist"
                        )
                }
            },
            locations![]
        )
    ]
[/#function]

[#function getErrorResponse errorCode responseCode=200 path="/index.html" ttl={}]
    [#return
        [
            {
                "ErrorCode" : errorCode,
                "ResponseCode" : responseCode,
                "ResponsePagePath" : path
            } +
            attributeIfContent("ErrorCachingMinTTL", ttl.Min!"")
        ]
    ]
[/#function]

[#macro createCFDistribution id dependencies=""
    aliases=[]
    cacheBehaviours=[]
    certificate={}
    comment=""
    customErrorResponses=[]
    defaultCacheBehaviour={}
    defaultRootObject=""
    isEnabled=true
    httpVersion="http2"
    logging={}
    origins=[]
    priceClass=""
    restrictions={}
    wafAclId=""
    tags={}
]
    [#local wafAclLink = (wafAclId?is_string)?then(getReference(wafAclId), wafAclId)]
    [@cfResource
       id=id
        type="AWS::CloudFront::Distribution"
        properties=
            {
                "DistributionConfig" :
                    {
                        "Enabled" : isEnabled,
                        "HttpVersion" : httpVersion
                    } +
                    attributeIfContent("Aliases", aliases) +
                    attributeIfContent("CacheBehaviors", cacheBehaviours) +
                    attributeIfContent("Comment", comment) +
                    attributeIfContent("CustomErrorResponses", customErrorResponses) +
                    attributeIfContent("DefaultCacheBehavior", defaultCacheBehaviour, asArray(defaultCacheBehaviour)[0]) +
                    attributeIfContent("DefaultRootObject", defaultRootObject) +
                    attributeIfContent("Logging", logging) +
                    attributeIfContent("Origins", origins) +
                    attributeIfContent("PriceClass", priceClass) +
                    attributeIfContent("Restrictions", restrictions) +
                    attributeIfContent("ViewerCertificate", certificate) +
                    attributeIfContent("WebACLId", wafAclLink)
            }
        outputs=CF_OUTPUT_MAPPINGS
        dependencies=dependencies
        tags=tags
    /]
[/#macro]

[#macro createCFOriginAccessIdentity id name dependencies="" ]
    [@cfResource
        id=id
        type="AWS::CloudFront::CloudFrontOriginAccessIdentity"
        properties=
            {
                "CloudFrontOriginAccessIdentityConfig" : {
                    "Comment" : name
                }
            }
        outputs=CF_ACCESS_ID_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]

[#macro createCFCachePolicy
        id
        name
        ttl
        cookieNames=[]
        headerNames=[]
        queryStringNames=[]
        compressionProtocols=[]  ]

    [@cfResource
        id=id
        type="AWS::CloudFront::CachePolicy"
        properties=
            {
                "CachePolicyConfig" : {
                    "Name": name,
                    "MinTTL": (ttl.Min)!0,
                    "MaxTTL": (ttl.Max)!0,
                    "DefaultTTL": (ttl.Default)!0,
                    "ParametersInCacheKeyAndForwardedToOrigin" : {
                        "CookiesConfig": {
                            "CookieBehavior": cookieNames?has_content?then(
                                cookieNames?seq_contains("_all")?then(
                                    "all",
                                    "whitelist"
                                ),
                                "none"
                            )
                        } +
                        attributeIfTrue(
                            "Cookies",
                            (cookieNames?has_content && ! cookieNames?seq_contains("_all")),
                            cookieNames
                        ),
                        "HeadersConfig" : {
                            "HeaderBehavior": headerNames?has_content?then(
                                "whitelist",
                                "none"
                            )
                        } +
                        attributeIfContent(
                            "Headers",
                            headerNames
                        ),
                        "QueryStringsConfig" : {
                            "QueryStringBehavior" : queryStringNames?has_content?then(
                                queryStringNames?seq_contains("_all")?then(
                                    "all",
                                    "whitelist"
                                ),
                                "none"
                            )
                        } +
                        attributeIfTrue(
                            "QueryStrings",
                            (queryStringNames?has_content && ! queryStringNames?seq_contains("_all")),
                            queryStringNames
                        ),
                        "EnableAcceptEncodingBrotli" : compressionProtocols?map(x -> x?lower_case)?seq_contains("brotli"),
                        "EnableAcceptEncodingGzip": compressionProtocols?map(x -> x?lower_case)?seq_contains("gzip")
                    }
                }
            }
    /]
[/#macro]

[#function getOriginFromLink
        id
        basePath
        customHeaders
        originLink
        tlsProtocols
        ConnectionTimeout ]

    [#local origins = []]

    [#switch originLink.Core.Type]
        [#case MOBILEAPP_COMPONENT_TYPE ]
            [#local spaBaslineProfile = originLink.Configuration.Solution.Profiles.Baseline ]
            [#local spaBaselineLinks = getBaselineLinks(originLink, [ "CDNOriginKey" ])]
            [#local spaBaselineComponentIds = getBaselineComponentIds(spaBaselineLinks)]
            [#local cfAccess = getExistingReference(spaBaselineComponentIds["CDNOriginKey"]!"")]

            [#local originBucket = originLink.State.Attributes["OTA_ARTEFACT_BUCKET"]]
            [#local originPrefix = originLink.State.Attributes["OTA_ARTEFACT_PREFIX"]]

            [#local origin =
                getCFS3Origin(
                    id,
                    originBucket,
                    cfAccess,
                    originPrefix
                )]
            [#local origins += origin ]
            [#break]

        [#case S3_COMPONENT_TYPE ]

            [#local spaBaslineProfile = originLink.Configuration.Solution.Profiles.Baseline ]
            [#local spaBaselineLinks = getBaselineLinks(originLink, [ "CDNOriginKey" ])]
            [#local spaBaselineComponentIds = getBaselineComponentIds(spaBaselineLinks)]
            [#local cfAccess = getExistingReference(spaBaselineComponentIds["CDNOriginKey"]!"")]

            [#local originBucket = originLink.State.Attributes["NAME"] ]

            [#local origin =
                getCFS3Origin(
                    id,
                    originBucket,
                    cfAccess,
                    basePath
                )]
            [#local origins += origin ]

            [#break]

        [#case SPA_COMPONENT_TYPE ]

            [#local spaBaslineProfile = originLink.Configuration.Solution.Profiles.Baseline ]
            [#local spaBaselineLinks = getBaselineLinks(originLink, [ "OpsData", "CDNOriginKey" ])]
            [#local spaBaselineComponentIds = getBaselineComponentIds(spaBaselineLinks)]
            [#local originBucket = getExistingReference(spaBaselineComponentIds["OpsData"]!"") ]
            [#local cfAccess = getExistingReference(spaBaselineComponentIds["CDNOriginKey"]!"")]

            [#local configPathPattern = originLink.State.Attributes["CONFIG_PATH_PATTERN"]]

            [#local spaOrigin =
                getCFS3Origin(
                    id,
                    originBucket,
                    cfAccess,
                    formatAbsolutePath(getSettingsFilePrefix(originLink), "spa")
                )]
            [#local origins += spaOrigin ]

            [#local configOrigin =
                getCFS3Origin(
                    formatId(id, "config"),
                    originBucket,
                    cfAccess,
                    formatAbsolutePath(getSettingsFilePrefix(originLink))
                )]
            [#local origins += configOrigin ]
            [#break]

        [#case LB_COMPONENT_TYPE ]
        [#case LB_PORT_COMPONENT_TYPE ]

            [#switch originLink.Core.Type ]
                [#case LB_COMPONENT_TYPE ]
                    [#local originHostName = originLink.State.Attributes["INTERNAL_FQDN"] ]
                    [#local originPath = formatAbsolutePath( "", basePath) ]
                    [#local originProtocol = "HTTPS" ]
                    [#local originPort = 443 ]
                    [#break]

                [#case LB_PORT_COMPONENT_TYPE ]
                    [#local originHostName = originLink.State.Attributes["FQDN"] ]
                    [#local originPath = formatAbsolutePath( originLink.State.Attributes["PATH"], basePath ) ]
                    [#local originProtocol = originLink.State.Attributes["PROTOCOL"]]
                    [#local originPort = originLink.State.Attributes["PORT"]]
                    [#break]
            [/#switch]

            [#local origin =
                        getCFHTTPOrigin(
                            id,
                            originHostName,
                            customHeaders,
                            originPath,
                            originProtocol,
                            originPort,
                            tlsProtocols,
                            connectionTimeout
                        )]
            [#local origins += origin ]
            [#break]

        [#case APIGATEWAY_COMPONENT_TYPE ]
            [#local origin = getCFHTTPOrigin(
                    id,
                    originLink.State.Attributes["FQDN"],
                    customHeaders,
                    formatAbsolutePath( originLink.State.Attributes["BASE_PATH"], basePath )
                )]
            [#local origins += origin ]
            [#break]

        [#case EXTERNALSERVICE_COMPONENT_TYPE ]

            [#local originHostName = originLink.State.Attributes["FQDN"]!'HamletFatal: Could not find FQDN Attribute on external service' ]

            [#local path = originLink.State.Attributes["PATH"]!'HamletFatal: Could not find PATH Attribute on external service' ]
            [#local originPath = formatAbsolutePath( path, basePath ) ]
            [#local protocol = (originLink.State.Attributes["PROTOCOL"])!"https" ]
            [#local port = (originLink.State.Attributes["PROTOCOL"])!443 ]

            [#local origin =
                        getCFHTTPOrigin(
                            id,
                            originHostName,
                            customHeaders,
                            originPath,
                            protocol,
                            port,
                            tlsProtocols,
                            connectionTimeout
                        )]
            [#local origins += origin ]
            [#break]
    [/#switch]

    [#return origins ]
[/#function]

[#function getOriginRequestPolicy
        output
        policy
        originLinkType
        customMethods
        customCookies=[]
        customHeaders=[]
        customQueryStringNames=[]
    ]

    [#-- Origin Request Policy --]
    [#local cookieNames = ["_all"]]
    [#local headerNames = ["_all"]]
    [#local queryStringNames = ["_all"]]
    [#local httpMethods = [ "DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT" ]]

    [#if policy == "LinkType" ]
        [#switch originLinkType ]
            [#case APIGATEWAY_COMPONENT_TYPE]
                [#local headerNames =
                    combineEntities(
                        [
                            "Accept",
                            "Accept-Charset",
                            "Accept-Datetime",
                            "Accept-Language",
                            "Authorization",
                            "Origin",
                            "Referer"
                        ],
                        customHeaders,
                        UNIQUE_COMBINE_BEHAVIOUR
                    )
                ]
                [#break]

            [#case MOBILEAPP_COMPONENT_TYPE]
            [#case S3_COMPONENT_TYPE]
            [#case SPA_COMPONENT_TYPE]
                [#local cookieNames = []]
                [#local headerNames = [
                    "Origin",
                    "Access-Control-Request-Headers",
                    "Access-Control-Request-Method"
                ]]
                [#local queryStringNames = []]
                [#local httpMethods = ["GET", "HEAD", "OPTIONS" ]]
                [#break]
        [/#switch]
    [/#if]

    [#if policy == "Custom"]
        [#local headerNames = customHeaders ]
        [#local cookieNames = customCookies ]
        [#local queryStringNames = customQueryStringNames ]
        [#local httpMethods = customMethods]
    [/#if]

    [#if output == "originRequestPolicy" ]
        [#return {
            "cookieNames": cookieNames,
            "headerNames": headerNames,
            "queryStringNames" : queryStringNames
        }]
    [/#if]

    [#if output == "behaviour" ]
        [#return {
            "httpMethods" : httpMethods
        }]
    [/#if]
[/#function]

[#macro createCFOriginRequestPolicy
        id
        name
        cookieNames=[]
        headerNames=[]
        queryStringNames=[] ]

    [#if headerNames?has_content ]
        [#if headerNames?seq_contains("_all") ]
            [#local headerBehaviour = "allViewer"]
        [#else]
            [#if headerNames?seq_contains("_cdn") ]
                [#local headerBehaviour = "allViewerAndWhitelistCloudFront"]
            [#else]
                [#local headerBehaviour = "whitelist"]
            [/#if]
        [/#if]
    [#else]
        [#local headerBehaviour = "none"]
    [/#if]

    [@cfResource
        id=id
        type="AWS::CloudFront::OriginRequestPolicy"
        properties=
            {
                "OriginRequestPolicyConfig": {
                    "Name": name,
                    "CookiesConfig": {
                        "CookieBehavior": cookieNames?has_content?then(
                            cookieNames?seq_contains("_all")?then(
                                "all",
                                "whitelist"
                            ),
                            "none"
                        )
                    } +
                    attributeIfTrue(
                        "Cookies",
                        (cookieNames?has_content && ! cookieNames?seq_contains("_all")),
                        cookieNames
                    ),
                    "QueryStringsConfig": {
                        "QueryStringBehavior": queryStringNames?has_content?then(
                            queryStringNames?seq_contains("_all")?then(
                                "all",
                                "whitelist"
                            ),
                            "none"
                        )
                    } +
                    attributeIfTrue(
                        "QueryStrings",
                        (queryStringNames?has_content && ! queryStringNames?seq_contains("_all")),
                        queryStringNames
                    ),
                    "HeadersConfig": {
                        "HeaderBehavior": headerBehaviour
                    } +
                    attributeIfTrue(
                        "Headers",
                        [
                            "allViewerAndWhitelistCloudFront",
                            "whitelist"
                        ]?seq_contains(headerBehaviour),
                        headerNames
                    )
                }
            }

    /]
[/#macro]

[#macro createCFResponseHeadersPolicy
        id
        name
        corsEnabled
        corsOverride
        corsPolicy
        securityHeadersEnabled
        securityHeadersOverride
        securityHeadersPolicy
        strictTransportSecurityEnabled
        strictTransportSecurityPolicy
        strictTransportSecurityOverride
        customHeaders ]

    [#local customHeaderProps = []]
    [#list customHeaders as id, customHeader]
        [#local customHeaderProps = combineEntities(
            customHeaderProps,
            [
                {
                    "Header" : (customHeader.Name)!id,
                    "Override" : (customHeader.Override)!customHeader.PreferOrigin,
                    "Value" : customHeader.Value
                }
            ],
            APPEND_COMBINE_BEHAVIOUR
        )]
    [/#list]

    [#local securityConfig = {}]
    [#if securityHeadersEnabled ]
        [#local securityConfig = mergeObjects(
            securityConfig,
            {} +
            attributeIfContent(
                "ContentSecurityPolicy"
                securityHeadersPolicy.ContentSecurityPolicy,
                {
                    "ContentSecurityPolicy": securityHeadersPolicy.ContentSecurityPolicy,
                    "Override" : securityHeadersOverride
                }
            ) +
            attributeIfTrue(
                "ContentTypeOptions",
                securityHeadersPolicy.ContentTypeOptions,
                {
                    "Override" : securityHeadersOverride
                }
            ) +
            attributeIfContent(
                "FrameOptions",
                securityHeadersPolicy.FrameOptions,
                {
                    "FrameOption" : (securityHeadersPolicy.FrameOptions)?upper_case,
                    "Override" : securityHeadersOverride
                }
            ) +
            attributeIfContent(
                "ReferrerPolicy",
                securityHeadersPolicy.ReferrerPolicy,
                {
                    "ReferrerPolicy" : securityHeadersPolicy.ReferrerPolicy,
                    "Override" : securityHeadersOverride
                }
            )
        )]
    [/#if]

    [#if strictTransportSecurityEnabled]
        [#local securityConfig = mergeObjects(
            securityConfig,
            {
                "StrictTransportSecurity" : {
                    "AccessControlMaxAgeSec": strictTransportSecurityPolicy.MaxAge,
                    "IncludeSubdomains" : strictTransportSecurityPolicy.IncludeSubdomains,
                    "Override" : strictTransportSecurityOverride
                }
            }
        )]
    [/#if]

    [@cfResource
        id=id
        type="AWS::CloudFront::ResponseHeadersPolicy"
        properties=
            {
                "ResponseHeadersPolicyConfig" : {
                    "Name": name
                } +
                attributeIfTrue(
                    "CorsConfig",
                    corsEnabled,
                    {
                        "AccessControlAllowCredentials": corsPolicy.AccessControlAllowCredentials,
                        "AccessControlAllowHeaders": {
                            "Items" : corsPolicy.AccessControlAllowHeaders
                        },
                        "AccessControlAllowMethods": {
                            "Items" : (corsPolicy.AccessControlAllowMethods)?map( x -> x?upper_case)
                        },
                        "AccessControlAllowOrigins": {
                            "Items" : corsPolicy.AccessControlAllowOrigins
                        },
                        "AccessControlExposeHeaders" : {
                            "Items" : corsPolicy.AccessControlExposeHeaders
                        },
                        "AccessControlMaxAgeSec" : corsPolicy.AccessControlMaxAgeSec,
                        "OriginOverride" : corsOverride
                    }
                ) +
                attributeIfContent(
                    "SecurityHeadersConfig",
                    securityConfig
                ) +
                attributeIfContent(
                    "CustomHeadersConfig",
                    customHeaders,
                    {
                        "Items" : customHeaders
                    }
                )
            }
    /]
[/#macro]
