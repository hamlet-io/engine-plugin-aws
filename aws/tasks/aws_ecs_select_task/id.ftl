[#ftl]

[@addTask
    type=AWS_ECS_SELECT_TASK_TASK_TYPE
    properties=[
            {
                "Type"  : "Description",
                "Value" : "List the running tasks for a service or task family and return the user selected task"
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
            "Names" : "ServiceName",
            "Description" : "The Arn or Name of a service deployed to the cluster",
            "Types" : STRING_TYPE
        },
        {
            "Names" : "TaskFamily",
            "Description" : "The name of a Task definition family that to show tasks for",
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
