[#ftl]

[@addTask
    type=AWS_CFN_CREATE_CHANGE_SET_TASK_TYPE
    properties=[
            {
                "Type"  : "Description",
                "Value" : "Create a change set for a cloudformation stack"
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
            "Names": "TemplateS3Uri",
            "Description": "An S3 Url to where the template is stored",
            "Types": STRING_TYPE
        },
        {
            "Names": "TemplateBody",
            "Description": "A string containing the template to deploy",
            "Types": STRING_TYPE
        },
        {
            "Names": "Parameters",
            "Description": "A JSON escaped string containing the paramters for the template",
            "Types" : STRING_TYPE
        },
        {
            "Names" : "Capabilities",
            "Description" : "A comma seperated list of capabilities that can be used in the template",
            "Default" : "CAPABILITY_IAM,CAPABILITY_NAMED_IAM"
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
