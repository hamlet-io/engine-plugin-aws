[#ftl]

[@addTask
    type=AWS_ECR_DOCKER_LOGIN_TASK_TYPE
    properties=[
            {
                "Type"  : "Description",
                "Value" : "Perfom a docker login using credentials from AWS ECR"
            }
        ]
    attributes=[
        {
            "Names" : "RegistryId",
            "Description" : "The Registry Id ( AWS Account Id) to login into",
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
