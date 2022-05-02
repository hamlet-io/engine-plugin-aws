[#ftl]

[#-- Resources --]
[#function formatDomainId ids...]
    [#return formatResourceId(
                "domain",
                ids)]
[/#function]

[#function formatSegmentDNSZoneId extensions...]
    [#return formatSegmentResourceId(
                "dnszone",
                extensions)]
[/#function]


[#assign AWS_ROUTE53_HEALTHCHECK_RESOURCE_TYPE = "route53HealthCheck" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ROUTE53_SERVICE
    resource=AWS_ROUTE53_HEALTHCHECK_RESOURCE_TYPE
/]

[#assign AWS_ROUTE53_HOSTED_ZONE_RESOURCE_TYPE = "route53hostedzone" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ROUTE53_SERVICE
    resource=AWS_ROUTE53_HOSTED_ZONE_RESOURCE_TYPE
/]

[#assign AWS_ROUTE53_RESOLVER_ENDPOINT_RESOURCE_TYPE = "route53ResolverEndpoint" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ROUTE53_SERVICE
    resource=AWS_ROUTE53_RESOLVER_ENDPOINT_RESOURCE_TYPE
/]

[#assign AWS_ROUTE53_RESOLVER_RULE_RESOURCE_TYPE = "route53ResolverRule" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ROUTE53_SERVICE
    resource=AWS_ROUTE53_RESOLVER_RULE_RESOURCE_TYPE
/]

[#assign AWS_ROUTE53_RESOLVER_RULE_ASSOC_RESOURCE_TYPE = "route53ResolverRuleAssoc" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ROUTE53_SERVICE
    resource=AWS_ROUTE53_RESOLVER_RULE_ASSOC_RESOURCE_TYPE
/]
