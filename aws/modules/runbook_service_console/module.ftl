[#ftl]

[@addModule
    name="runbook_service_exec_command"
    description="Run an interactive command on a container running as part of a service using ecs exec"
    provider=AWS_PROVIDER
    properties=[
        {
            "Names" : "id",
            "Description" : "A unique id for this exec command - allows for multiple commands on the same service",
            "Types" : STRING_TYPE,
            "Default" : "sh"
        },
        {
            "Names" : "serviceLink",
            "Description" : "A Link to a service you want to open the shell on",
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
            "Names" : "command",
            "Description" : "The command to run on the container",
            "Types" : STRING_TYPE,
            "Default" : "/bin/sh"
        }
    ]
/]

[#macro aws_module_runbook_service_exec_command
        id
        serviceLink
        command
        containerId ]


    [#local componentId = ((serviceLink.SubComponent)!serviceLink.Service)!"" ]

    [@loadModule
        blueprint={
            "Tiers" : {
                serviceLink.Tier : {
                    "Components" : {
                        "${componentId}-exec_command-${id}" : {
                            "Description" : "Runs an interactive command on a service container",
                            "Type" : "runbook",
                            "Engine" : "hamlet",
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
                                "select_task" : {
                                    "Priority" : 10,
                                    "Extensions" : [ "_runbook_get_region" ],
                                    "Task" : {
                                        "Type" : "aws_ecs_select_task",
                                        "Parameters" : {
                                            "ClusterArn" : {
                                                "Value" : "__attribute:service:CLUSTER_ARN__"
                                            },
                                            "ServiceName" : {
                                                "Value" : "__attribute:service:ARN__"
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
                                        "service" : serviceLink
                                    }
                                },
                                "run_command" : {
                                    "Priority" : 10,
                                    "Extensions" : [ "_runbook_get_region" ],
                                    "Task" : {
                                        "Type" : "aws_ecs_run_command",
                                        "Parameters" : {
                                            "ClusterArn" : {
                                                "Value" : "__attribute:service:CLUSTER_ARN__"
                                            },
                                            "Command" : {
                                                "Value" : command
                                            },
                                            "ContainerName" : {
                                                "Value" : containerId?split("-")[0]
                                            },
                                            "TaskArn" : {
                                                "Value" : "__output:select_task:result__"
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
                                        "service" : serviceLink
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "DeploymentProfiles" : {
                "${serviceLink.Tier}_${componentId}_ecs-exec" : {
                    "Modes" : {
                        "*" : {
                            "service" : {
                                "aws:ExecuteCommand" : true,
                                "Containers" : {
                                    containerId : {
                                        "InitProcess" : true
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
