[#ftl]

[@addTask
    type=AWS_RUN_BASH_SCRIPT_TASK_TYPE
    properties=[
            {
                "Type"  : "Description",
                "Value" : "Run a provided bash script with AWS Credentials set in the environment"
            }
        ]
    attributes=[
        {
            "Names": "ScriptPath",
            "Description": "The path to the script to run",
            "Types": STRING_TYPE,
            "Mandatory": true
        },
        {
            "Names": "Environment",
            "Description": "A json escaped dict with k/v environment variable pairs",
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
