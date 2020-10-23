[#ftl]

[#-- Resources --]
[#assign AWS_TRANSFER_SERVER_RESOURCE_TYPE = "transferServer" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_TRANSFER_SERVICE
    resource=AWS_TRANSFER_SERVER_RESOURCE_TYPE
/]
[#assign AWS_TRANSFER_USER_RESOURCE_TYPE = "transferUser" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_TRANSFER_SERVICE
    resource=AWS_TRANSFER_USER_RESOURCE_TYPE
/]
