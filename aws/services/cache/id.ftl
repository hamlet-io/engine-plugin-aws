[#ftl]

[#-- Resources --]
[#assign AWS_CACHE_RESOURCE_TYPE = "cache" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTICACHE_SERVICE
    resource=AWS_CACHE_RESOURCE_TYPE
/]
[#assign AWS_CACHE_SUBNET_GROUP_RESOURCE_TYPE = "cacheSubnetGroup" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTICACHE_SERVICE
    resource=AWS_CACHE_SUBNET_GROUP_RESOURCE_TYPE
/]
[#assign AWS_CACHE_PARAMETER_GROUP_RESOURCE_TYPE = "cacheParameterGroup" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTICACHE_SERVICE
    resource=AWS_CACHE_PARAMETER_GROUP_RESOURCE_TYPE
/]
