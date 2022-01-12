[#ftl]

[@addTask
    type=AWS_ECS_RUN_COMMAND_TASK_TYPE
    properties=[
            {
                "Type"  : "Description",
                "Value" : "Runs an interactive task on a provided task arn"
            }
        ]
    attributes=[
        {
            "Names" : "ClusterArn",
            "Description" : "The ARN of the ECS Cluster to list running tasks from",
            "Types" : STRING_TYPE,
            "Mandatory" : true
        },
        {
            "Names" : "TaskArn",
            "Description" : "The Arn or Name of a running task to run the command on",
            "Types" : STRING_TYPE,
            "Mandatory" : true
        },
        {
            "Names" : "Command",
            "Description" : "The command to run in the command",
            "Types" : STRING_TYPE
        },
        {
            "Names" : "ContainerName",
            "Description" : "The name of the container in the task definition",
            "Types" : STRING_TYPE
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
