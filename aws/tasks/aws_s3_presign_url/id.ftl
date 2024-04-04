[#ftl]

[@addTask
    type=AWS_S3_PRESIGN_URL_TASK_TYPE
    properties=[
            {
                "Type"  : "Description",
                "Value" : "Return a presigned URL for an S3 object"
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
            "Names": "ClientMethod",
            "Description": "The aws s3 methods that can be performed on the object - comma seperated",
            "Values" : [ "get_object" ],
            "Types": STRING_TYPE,
            "Default": "get_object"
        },
        {
            "Names": "Expiration",
            "Description": "The expiration time in seconds for the presigned URL",
            "Types": [ NUMBER_TYPE, STRING_TYPE],
            "Default": 300
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
