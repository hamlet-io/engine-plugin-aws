[#ftl]

[@addModule
    name="service"
    description="Testing module for the aws ecs service component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_service ]

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
                "Namespace" : "mockedup-integration-app-servicebase_ecs-servicebase",
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
                        "servicebase_ecs" : {
                            "Type": "ecs",
                            "deployment:Unit": "aws-service",
                            "Profiles" : {
                                "Deployment": ["_awslinux2"]
                            },
                            "Services" : {
                                "servicebase" : {
                                    "deployment:Unit" : "aws-service",
                                    "Profiles" : {
                                        "Testing" : [ "servicebase" ]
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
                "servicebase" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "service" : {
                                    "Name" : "ecsServiceXappXservicebaseXecsXservicebase",
                                    "Type" : "AWS::ECS::Service"
                                }
                            },
                            "Output" : [
                                "ecsServiceXappXservicebaseXecsXservicebaseXname",
                                "ecsServiceXappXservicebaseXecsXservicebase",
                                "ecsTaskXappXservicebaseXecsXservicebaseXarn"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "TagName" : {
                                    "Path"  : "Resources.ecsServiceXappXservicebaseXecsXservicebase.Properties.Tags[10].Value",
                                    "Value" : "mockedup-integration-application-servicebase_ecs-servicebase"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "servicebase" : {
                    "service" : {
                        "TestCases" : [ "servicebase" ]
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

                "ecsXappXservicebaseXecs": "mockedup-integration-application-serviceecsbase",
                "ecsXappXservicebaseXecsXarn": "arn:aws:ecs:mock-region-1:0123456789:cluster/mockedup-integration-application-serviceecsbase",
                "ecsCapacityProviderXappXservicebaseXecsXasg": "mockedup-integration-application-serviceecsbase",
                "ecsCapacityProviderAssocXappXservicebaseXecs": "mockedup-integration-application-serviceecsbase"
            }
        ]
    /]

[/#macro]
