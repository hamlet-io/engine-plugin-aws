[#ftl]

[@addModule
    name="task"
    description="Testing module for the aws ecs task component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]


[#macro awstest_module_task ]

    [#-- Base setup --]
    [@loadModule
        settingSets=[
            {
                "Type" : "Settings",
                "Scope" : "Accounts",
                "Namespace" : "mockacct-shared",
                "Settings" : {
                    "Registries": {
                        "docker": {
                            "EndPoint": "123456789.ecr.awsamazon.com"
                        }
                    }
                }
            },
            {
                "Type" : "Builds",
                "Scope" : "Products",
                "Namespace" : "mockedup-integration-aws-task-base",
                "Settings" : {
                    "COMMIT" : "123456789#MockCommit#",
                    "FORMATS" : ["docker"]
                }
            }
        ]

        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "taskecsbase" : {
                            "ecs" : {
                                "Instances" : {
                                    "default" : {
                                        "deployment:Unit" : "aws-task-ecs"
                                    }
                                },
                                "Tasks" : {
                                    "taskbase" : {
                                        "Instances" : {
                                            "default" : {
                                                "deployment:Unit" : "aws-task-base"
                                            }
                                        },
                                        "Profiles" : {
                                            "Testing" : [ "taskbase" ]
                                        },
                                        "Containers" : {
                                            "containerbase" : {
                                                "MemoryReservation" : 512
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "taskbase" : {
                    "OutputSuffix" : "template.json",
                    "Tools" : {
                       "CFNLint" : true
                    },
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "task" : {
                                    "Name" : "ecsTaskXappXtaskecsbaseXtaskbase",
                                    "Type" : "AWS::ECS::TaskDefinition"
                                }
                            },
                            "Output" : [
                                "ecsTaskXappXtaskecsbaseXtaskbase",
                                "ecsTaskXappXtaskecsbaseXtaskbaseXarn"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "TagName" : {
                                    "Path"  : "Resources.ecsTaskXappXtaskecsbaseXtaskbase.Properties.Tags[10].Value",
                                    "Value" : "application-taskecsbase-taskbase"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "taskbase" : {
                    "task" : {
                        "TestCases" : [ "taskbase" ]
                    }
                }
            }
        }
    /]

[/#macro]
