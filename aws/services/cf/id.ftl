[#ftl]

[#-- Resources --]
[#assign AWS_CLOUDFRONT_DISTRIBUTION_RESOURCE_TYPE = "cf" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_CLOUDFRONT_SERVICE
    resource=AWS_CLOUDFRONT_DISTRIBUTION_RESOURCE_TYPE
/]

[#assign AWS_CLOUDFRONT_ACCESS_ID_RESOURCE_TYPE = "cfaccess" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_CLOUDFRONT_SERVICE
    resource=AWS_CLOUDFRONT_ACCESS_ID_RESOURCE_TYPE
/]

[#assign AWS_CLOUDFRONT_ORIGIN_RESOURCE_TYPE = "cforigin" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_CLOUDFRONT_SERVICE
    resource=AWS_CLOUDFRONT_ORIGIN_RESOURCE_TYPE
/]

[#assign AWS_CLOUDFRONT_BEHAVIOUR_RESOURCE_TYPE = "cfbehaviour" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_CLOUDFRONT_SERVICE
    resource=AWS_CLOUDFRONT_BEHAVIOUR_RESOURCE_TYPE
/]

[#assign AWS_CLOUDFRONT_CACHE_POLICY_RESOURCE_TYPE = "cfcachepolicy" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_CLOUDFRONT_SERVICE
    resource=AWS_CLOUDFRONT_CACHE_POLICY_RESOURCE_TYPE
/]

[#assign AWS_CLOUDFRONT_ORIGIN_REQUEST_POLICY_RESOURCE_TYPE = "cforiginrequestpolicy" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_CLOUDFRONT_SERVICE
    resource=AWS_CLOUDFRONT_ORIGIN_REQUEST_POLICY_RESOURCE_TYPE
/]

[#assign AWS_CLOUDFRONT_RESPONSE_HEADERS_POLICY_RESOURCE_TYPE = "cfresponseheaderspolicy" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_CLOUDFRONT_SERVICE
    resource=AWS_CLOUDFRONT_RESPONSE_HEADERS_POLICY_RESOURCE_TYPE
/]

[#function formatDependentCFDistributionId resourceId extensions...]
    [#return formatDependentResourceId(
                AWS_CLOUDFRONT_DISTRIBUTION_RESOURCE_TYPE,
                resourceId,
                extensions)]
[/#function]

[#function formatComponentCFDistributionId tier component extensions...]
    [#return formatComponentResourceId(
                AWS_CLOUDFRONT_DISTRIBUTION_RESOURCE_TYPE,
                tier,
                component,
                extensions)]
[/#function]

[#function formatDependentCFAccessId resourceId extensions...]
    [#return formatDependentResourceId(
                AWS_CLOUDFRONT_ACCESS_ID_RESOURCE_TYPE,
                resourceId,
                extensions)]
[/#function]
