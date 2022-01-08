[#ftl]

[@addTask
    type=AWS_EC2_SELECT_INSTANCE_TASK_TYPE
    properties=[
            {
                "Type"  : "Description",
                "Value" : "Lists the available instances and allows the user to select one - returns the selected instance id"
            }
        ]
    attributes=[
        {
            "Names" : "VpcId",
            "Description" : "The VPCId that instances are assiged to",
            "Types" : STRING_TYPE
        },
        {
            "Names" : "Tags",
            "Description" : "An object of Key=Value tags that the instances must have",
            "Types" : OBJECT_TYPE
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
