[#ftl]

[#-- Resources --]

[#assign AWS_ATHENA_WORKGROUP_RESOURCE_TYPE = "athenaworkgroup" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ATHENA_SERVICE
    resource=AWS_ATHENA_WORKGROUP_RESOURCE_TYPE
/]
