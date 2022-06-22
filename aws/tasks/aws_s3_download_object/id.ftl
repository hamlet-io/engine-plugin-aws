[#ftl]

[@addTask
    type=AWS_S3_DOWNLOAD_OBJECT_TASK_TYPE
    properties=[
            {
                "Type"  : "Description",
                "Value" : "Download a file from an S3 bucket to a local path"
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
            "Names": "Object",
            "Description" : "The path of the object in the bucket",
            "Types" : STRING_TYPE,
            "Mandatory" : true
        },
        {
            "Names": "LocalPath",
            "Description" : "The local path to download the object to",
            "Types" : STRING_TYPE,
            "Mandatory" : true
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
