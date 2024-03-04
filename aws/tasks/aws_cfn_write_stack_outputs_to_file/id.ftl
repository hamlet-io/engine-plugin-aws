[#ftl]

[@addTask
    type=AWS_CFN_WRITE_STACK_OUTPUTS_TO_FILE_TASK_TYPE
    properties=[
            {
                "Type"  : "Description",
                "Value" : "Get the outputs of a stack and write them to file"
            }
        ]
    attributes=[
        {
            "Names": "StackName",
            "Description": "The name to use for the stack",
            "Types": STRING_TYPE,
            "Mandatory": true
        },
        {
            "Names" : "Region",
            "Description" : "The name of the region to use for the aws session",
            "Types" : STRING_TYPE
        },
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
        },
        {
            "Names": "FilePath",
            "Description": "The path to where the file should be written",
            "Types" : STRING_TYPE,
            "Mandatory" : true
        }
    ]
/]
