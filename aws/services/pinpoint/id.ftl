[#ftl]

[#-- Resources --]
[#assign AWS_PINPOINT_RESOURCE_TYPE = "pinpoint"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_PINPOINT_SERVICE
    resource=AWS_PINPOINT_RESOURCE_TYPE
/]