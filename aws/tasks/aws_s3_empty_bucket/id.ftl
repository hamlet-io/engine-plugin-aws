[#ftl]

[@addTask
    type=AWS_S3_EMPTY_BUCKET_TASK_TYPE
    properties=[
            {
                "Type"  : "Description",
                "Value" : "Delete all versions of objects in an S3 Bucket"
            }
        ]
    attributes=[
        {
            "Names" : "BucketName",
            "Description" : "The name of the S3 Bucket",
            "Types" : STRING_TYPE,
            "Mandatory" : true
        },
        {
            "Names": "Prefix",
            "Description" : "A prefix required for all items to download",
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
