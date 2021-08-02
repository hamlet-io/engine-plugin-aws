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
                                        "deployment:Unit" : "aws-task-base-ecs"
                                    }
                                },
                                "Profiles" : {
                                    "Testing" : [ "baseecs" ]
                                },
                                "Services" : {
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
                "baseecs" : {
                    "OutputSuffix" : "template.json",
                    "Tools" : {
                       "CFNLint" : true
                    }
                },
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
                                "ecsServiceXappXtaskecsbaseXtaskbaseXname",
                                "ecsServiceXappXtaskecsbaseXtaskbase",
                                "ecsTaskXappXtaskecsbaseXtaskbaseXarn"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "TagName" : {
                                    "Path"  : "Resources.ecsTaskXappXtaskecsbaseXtaskbase.Properties.Tags[10].Value",
                                    "Value" : "mockedup-integration-application-taskecsbase-taskbase"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "baseecs" : {
                    "service" : {
                        "TestCases" : [ "baseecs" ]
                    }
                },
                "taskbase" : {
                    "service" : {
                        "TestCases" : [ "taskbase" ]
                    }
                }
            }
        }
    /]

[/#macro]
