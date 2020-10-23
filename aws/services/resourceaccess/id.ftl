[#ftl]

[#-- Resources --]
[#assign AWS_RESOURCEACCESS_SHARE_RESOURCE_TYPE = "resourceAccessShare" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_RESOURCE_ACCESS_SERVICE
    resource=AWS_RESOURCEACCESS_SHARE_RESOURCE_TYPE
/]
