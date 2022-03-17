[#ftl]

[@addTask
    type=AWS_ECS_RUN_TASK_TASK_TYPE
    properties=[
            {
                "Type"  : "Description",
                "Value" : "Run an ecs task with provided overrided and wait for it to run or to run and stop"
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
            "Names" : "TaskFamily",
            "Description" : "The name of a Task definition family that to show tasks for",
            "Types" : STRING_TYPE,
            "Mandatory" : true
        },
        {
            "Names" : "ContainerName",
            "Description" : "The name of the container to apply overrrides and watch for exit status",
            "Mandatory" : true,
            "Types" : STRING_TYPE
        },
        {
            "Names" : "CapacityProvider",
            "Description" : "The capacity provider used to host the task",
            "Types" : STRING_TYPE
        },
        {
            "Names" : "SubnetIds",
            "Description" : "A comma seperated list of subnetIds the task can be hosted in",
            "Types" : STRING_TYPE
        },
        {
            "Names" : "SecurityGroupIds",
            "Description" : "A comma seperated list of security group ids to apply to task interfaces",
            "Types" : STRING_TYPE
        },
        {
            "Names" : "PublicIP",
            "Description" : "Assign a public IP address to the task",
            "Types" : [ BOOLEAN_TYPE, STRING_TYPE],
            "Values" : [ "true", "false"],
            "Default" : false
        },
        {
            "Names" : "CommandOverride",
            "Description" : "A json escaped string array or string with an override of the container command",
            "Types" : STRING_TYPE
        },
        {
            "Names" : "EnvironmentOverrides",
            "Description" : "A json escaped object string or string with overrides for environment variables",
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
