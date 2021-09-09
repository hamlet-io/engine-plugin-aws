[#ftl]

[#-- Resources --]
[#assign AWS_DIRECTORY_RESOURCE_TYPE = "directory" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_DIRECTORY_SERVICE
    resource=AWS_DIRECTORY_RESOURCE_TYPE
/]
