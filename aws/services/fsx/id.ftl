[#ftl]

[#-- Resources --]
[#assign AWS_FSX_FILESYSTEM_RESOURCE_TYPE = "fsxfilesystem" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_FSX_SERVICE
    resource=AWS_FSX_FILESYSTEM_RESOURCE_TYPE
/]
