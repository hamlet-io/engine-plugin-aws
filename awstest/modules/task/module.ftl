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
                "Namespace" : "mockedup-integration-app-taskbase_ecs-taskbase",
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
                        "taskbase_ecs" : {
                            "Type": "ecs",
                            "deployment:Unit" : "aws-task",
                            "Profiles": {
                                "Deployment": ["_awslinux2"]
                            },
                            "Tasks" : {
                                "taskbase" : {
                                    "deployment:Unit" : "aws-task",
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
            },
            "TestCases" : {
                "taskbase" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "task" : {
                                    "Name" : "ecsTaskXappXtaskbaseXecsXtaskbase",
                                    "Type" : "AWS::ECS::TaskDefinition"
                                }
                            },
                            "Output" : [
                                "ecsTaskXappXtaskbaseXecsXtaskbase",
                                "ecsTaskXappXtaskbaseXecsXtaskbaseXarn"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "TagName" : {
                                    "Path"  : "Resources.ecsTaskXappXtaskbaseXecsXtaskbase.Properties.Tags[10].Value",
                                    "Value" : "application-taskbase_ecs-taskbase"
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
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
        stackOutputs=[
            {
                "Account" : "0123456789",
                "Region" : "mock-region-1",
                "DeploymentUnit" : "aws-s3",

                "ecsXappXtaskbaseXecs": "mockedup-integration-application-taskecsbase",
                "ecsXappXtaskbaseXecsXarn": "arn:aws:ecs:mock-region-1:0123456789:cluster/mockedup-integration-application-taskecsbase",
                "ecsCapacityProviderXappXtaskbaseXecsXasg": "mockedup-integration-application-taskecsbase",
                "ecsCapacityProviderAssocXappXtaskbaseXecs": "mockedup-integration-application-taskecsbase"
            }
        ]
    /]

[/#macro]
