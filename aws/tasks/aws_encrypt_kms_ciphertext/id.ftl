[#ftl]

[@addTask
    type=AWS_KMS_ENCRYPT_VALUE_TASK_TYPE
    properties=[
            {
                "Type"  : "Description",
                "Value" : "Given a value return the KMS encrypted ciphertext as the result"
            }
        ]
    attributes=[
        {
            "Names" : "Value",
            "Description" : "The value that needs to be encrypted",
            "Types" : STRING_TYPE,
            "Mandatory" : true
        },
        {
            "Names" : "Base64Encode",
            "Description" : "Return the ciphertext as a base64 encoded string",
            "Types" : BOOLEAN_TYPE,
            "Default" : true
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
