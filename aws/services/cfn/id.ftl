[#ftl]

[#-- Resources --]
[#assign AWS_CLOUDFORMATION_STACK_RESOURCE_TYPE = "cfnstack" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_CLOUDFORMATION_SERVICE
    resource=AWS_CLOUDFORMATION_STACK_RESOURCE_TYPE
/]

[#assign AWS_CLOUDFORMATION_WAIT_HANDLE_RESOURCE_TYPE = "cfnwaithandle" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_CLOUDFORMATION_SERVICE
    resource=AWS_CLOUDFORMATION_WAIT_HANDLE_RESOURCE_TYPE
/]

[#assign AWS_CLOUDFORMATION_WAIT_CONDITION_RESOURCE_TYPE = "cfnwaitcondition"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_CLOUDFORMATION_SERVICE
    resource=AWS_CLOUDFORMATION_WAIT_CONDITION_RESOURCE_TYPE
/]
