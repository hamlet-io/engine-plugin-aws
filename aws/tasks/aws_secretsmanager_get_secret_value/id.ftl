[#ftl]

[@addTask
    type=AWS_SECRETSMANAGER_GET_SECRET_VALUE_TASK_TYPE
    properties=[
            {
                "Type"  : "Description",
                "Value" : "Get the value of a secret stored in secrets manager"
            }
        ]
    attributes=[
        {
            "Names" : "SecretArn",
            "Description" : "The name of the S3 Bucket",
            "Types" : STRING_TYPE,
            "Mandatory" : true
        },
        {
            "Names": "JSONKeyPath",
            "Description" : "A path to the key as JMES path for the value",
            "Types" : STRING_TYPE,
            "Default": ""
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
