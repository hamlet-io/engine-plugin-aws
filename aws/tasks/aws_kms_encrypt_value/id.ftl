[#ftl]

[@addTask
    type=AWS_KMS_ENCRYPT_VALUE_TASK_TYPE
    properties=[
            {
                "Type"  : "Description",
                "Value" : "Given a value return the a base64 encoded string of the KMS Symetric encrypted ciphertext"
            }
        ]
    attributes=[
        {
            "Names" : "KeyArn",
            "Description" : "The Arn of the kms key or alias to encrypt the value with",
            "Types" : STRING_TYPE,
            "Mandatory" : true
        },
        {
            "Names" : "Value",
            "Description" : "The value that needs to be encrypted",
            "Types" : STRING_TYPE,
            "Mandatory" : true
        },
        {
            "Names" : "EncryptionScheme",
            "Description" : "A scheme style prefix to add to the base64 encoded value",
            "Types" : STRING_TYPE,
            "Default" : ""
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
