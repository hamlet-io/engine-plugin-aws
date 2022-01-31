[#ftl]

[@addModule
    name="runbook_run_task"
    description="Run an ecs task to perform a single command and exit"
    provider=AWS_PROVIDER
    properties=[
        {
            "Names" : "id",
            "Description" : "A unique id for this exec command - allows for multiple commands on the same service",
            "Types" : STRING_TYPE,
            "Default" : "sh"
        },
        {
            "Names" : "taskLink",
            "Description" : "A Link to a task that will be started to run the command",
            "Mandatory" : true,
            "AttributeSet" : LINK_ATTRIBUTESET_TYPE
        },
        {
            "Names" : "containerId",
            "Description" : "The id of the container to run the command on",
            "Types" : STRING_TYPE,
            "Mandatory" : true
        },
        {
            "Names" : "Inputs",
            "Description" : "Inputs requred from to run the task",
            "Types" : ARRAY_OF_STRING_TYPE,
            "Values" : [ "command", "environment" ]
        },
        {
            "Names" : "command",
            "Description" : "A fixed command to run on the container",
            "Types" : STRING_TYPE
        },
        {
            "Names" : "environment",
            "Description" : "A fixed environment variable overrides to apply to the command",
            "Types" : STRING_TYPE
        }
    ]
/]

[#macro aws_module_runbook_run_task
        id
        taskLink
        containerId
        inputs
        command
        environment ]


    [#local componentId = ((taskLink.SubComponent)!taskLink.Task)!"" ]

    [@loadModule
        blueprint={
            "Tiers" : {
                taskLink.Tier : {
                    "Components" : {
                        "${componentId}-exec_command-${id}" : {
                            "Description" : "Runs an interactive command on a service container",
                            "Type" : "runbook",
                            "Engine" : "hamlet",
                            "Inputs" : {} +
                                attributeIfTrue(
                                    "command",
                                    inputs?seq_contains("command"),
                                    {
                                        "Types" : STRING_TYPE,
                                        "Description" : "The command to run on the container",
                                        "Mandatory" : true
                                    }
                                ) +
                                attributeIfTrue(
                                    "environment",
                                    inputs?seq_contains("environment"),
                                    {
                                        "Types" : STRING_TYPE,
                                        "Description" : "A JSON escaped string of the environment vars to override",
                                        "Mandatory" : true
                                    }
                                ),
                            "Steps" : {
                                "aws_login" : {
                                    "Priority" : 5,
                                    "Extensions" : [ "_runbook_get_provider_id" ],
                                    "Task" : {
                                        "Type" : "set_provider_credentials",
                                        "Parameters" : {
                                            "Account" : {
                                                "Value" : "__setting:ACCOUNT__"
                                            }
                                        }
                                    }
                                },
                                "run_task" : {
                                    "Priority" : 10,
                                    "Extensions" : [ "_runbook_get_region" ],
                                    "Task" : {
                                        "Type" : "aws_ecs_run_task",
                                        "Parameters" : {
                                            "ClusterArn" : {
                                                "Value" : "__attribute:task:CLUSTER_ARN__"
                                            },
                                            "TaskFamily" : {
                                                "Value" : "__attribute:task:DEFINITION__"
                                            },
                                            "OverrideContainerName" : {
                                                "Value" : containerId?split("-")[0]
                                            },
                                            "CommandOverride" : {
                                                "Value" : command
                                            },
                                            "EnvironmentOverrides" : {
                                                "Value" : environment
                                            },
                                            "CapacityProvider" : {
                                                "Value" : ""
                                            },
                                            "SubnetIds" : {
                                                "Value" : "__attribute:task:SUBNET__"
                                            },
                                            "SecurityGroupIds" : {
                                                "Value" : "__attribute:task:SECURITY_GROUP__"
                                            },
                                            "AWSAccessKeyId" : {
                                                "Value" : "__output:aws_login:aws_access_key_id__"
                                            },
                                            "AWSSecretAccessKey" : {
                                                "Value" : "__output:aws_login:aws_secret_access_key__"
                                            },
                                            "AWSSessionToken" : {
                                                "Value" : "__output:aws_login:aws_session_token__"
                                            }
                                        }
                                    },
                                    "Links" : {
                                        "task" : taskLink
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    /]
[/#macro]
