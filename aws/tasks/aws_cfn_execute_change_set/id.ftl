[#ftl]

[@addTask
    type=AWS_CFN_EXECUTE_CHANGE_SET_TASK_TYPE
    properties=[
            {
                "Type"  : "Description",
                "Value" : "Execute a change set for a cloudformation stack"
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
            "Names": "ChangeSetName",
            "Description": "The name of the change set to create",
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
        }
    ]
/]
