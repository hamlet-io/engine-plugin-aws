[#ftl]

[#-- Resources --]
[#assign AWS_CLOUDMAP_DNS_NAMESPACE_RESOURCE_TYPE = "cloudmapdnsnamespace" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_CLOUDMAP_SERVICE
    resource=AWS_CLOUDMAP_DNS_NAMESPACE_RESOURCE_TYPE
/]

[#assign AWS_CLOUDMAP_SERVICE_RESOURCE_TYPE = "cloudmapservice" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_CLOUDMAP_SERVICE
    resource=AWS_CLOUDMAP_SERVICE_RESOURCE_TYPE
/]
[#assign AWS_CLOUDMAP_INSTANCE_RESOURCE_TYPE = "cloudmapinstance" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_CLOUDMAP_SERVICE
    resource=AWS_CLOUDMAP_INSTANCE_RESOURCE_TYPE
/]
