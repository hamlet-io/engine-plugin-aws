[#ftl]

[#-- Resources --]
[#assign AWS_SQS_RESOURCE_TYPE = "sqs" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_SIMPLE_QUEUEING_SERVICE
    resource=AWS_SQS_RESOURCE_TYPE
/]
[#assign AWS_SQS_POLICY_RESOURCE_TYPE  = "sqsPolicy" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_SIMPLE_QUEUEING_SERVICE
    resource=AWS_SQS_POLICY_RESOURCE_TYPE
/]
