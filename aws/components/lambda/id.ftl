[#ftl]
[@addResourceGroupInformation
    type=LAMBDA_COMPONENT_TYPE
    attributes=[]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_LAMBDA_SERVICE
        ]
/]

[@addResourceGroupInformation
    type=LAMBDA_FUNCTION_COMPONENT_TYPE
    attributes=[]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_CLOUDWATCH_SERVICE,
            AWS_IDENTITY_SERVICE,
            AWS_LAMBDA_SERVICE,
            AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE,
            AWS_SIMPLE_STORAGE_SERVICE,
            AWS_KEY_MANAGEMENT_SERVICE,
            AWS_SIMPLE_NOTIFICATION_SERVICE,
            AWS_IMAGE_SERVICE
        ]
/]


[@addResourceGroupAttributeValues
    type=LAMBDA_FUNCTION_COMPONENT_TYPE
    provider=AWS_PROVIDER
    extensions=[
        {
            "Names" : "EventSources",
            "Description": "Control how event sources are processed for AWS specific services",
            "Children" : [
                {
                    "Names" : "SQS",
                    "Description" : "SQS specific controls",
                    "Children" : [
                        {
                            "Names" : "BatchSize",
                            "Description" : "How many messages to pull from the queue in a batch",
                            "Types" : NUMBER_TYPE,
                            "Default" : 1
                        },
                        {
                            "Names" : "ReportBatchItemFailures",
                            "Description" : "Report the status of particular items that failed in the batch",
                            "Types" : BOOLEAN_TYPE,
                            "Default": false
                        },
                        {
                            "Names" : "MaximumBatchingWindow",
                            "Description" : "How long to gather records for batch processing",
                            "Types": NUMBER_TYPE,
                            "Default": 0
                        }
                    ]
                }
            ]
        }
    ]
/]
