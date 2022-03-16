[#ftl]

[@addTask
    type=AWS_LAMBDA_INVOKE_FUNCTION_TASK_TYPE
    properties=[
            {
                "Type"  : "Description",
                "Value" : "Invoke a lambda function with a payload and return the returned payload"
            }
        ]
    attributes=[
        {
            "Names" : "FunctionArn",
            "Description" : "The ARN of the lambda function",
            "Types" : STRING_TYPE
        },
        {
            "Names" : "Payload",
            "Description" : "A json encoded string with the lambda payload",
            "Types" : STRING_TYPE
        },
        {
            "Names" : "Region",
            "Description" : "The name of the region to use for the aws session",
            "Types" : STRING_TYPE
        }
        {
            "Names" : "AWSAccessKeyId",
            "Description" : "The AWS Access Key Id with access to decrypt",
            "Types" : STRING_TYPE
        },
        {
            "Names" : "AWSSecretAccessKey",
            "Description" : "The AWS Secret Access Key with access to decrypt",
            "Types" : STRING_TYPE
        },
        {
            "Names" : "AWSSessionToken",
            "Description" : "The AWS Session Token with access to decrypt",
            "Types" : STRING_TYPE
        }
    ]
/]
