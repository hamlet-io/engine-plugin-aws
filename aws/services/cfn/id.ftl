[#ftl]

[#-- Resources --]
[#assign AWS_CLOUDFORMATION_STACK_RESOURCE_TYPE = "cfnstack" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_CLOUDFORMATION_SERVICE
    resource=AWS_CLOUDFORMATION_STACK_RESOURCE_TYPE
/]
