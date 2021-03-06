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
                "Namespace" : "mockedup-integration-aws-service-base",
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
                        "serviceecsbase" : {
                            "ecs" : {
                                "Instances" : {
                                    "default" : {
                                        "deployment:Unit" : "aws-service-base-ecs"
                                    }
                                },
                                "Services" : {
                                    "servicebase" : {
                                        "Instances" : {
                                            "default" : {
                                                "deployment:Unit" : "aws-service-base"
                                            }
                                        },
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
                }
            },
            "TestCases" : {
                "servicebase" : {
                    "OutputSuffix" : "template.json",
                    "Tools" : {
                       "CFNLint" : true
                    }
                }
            },
            "TestProfiles" : {
                "servicebase" : {
                    "service" : {
                        "TestCases" : [ "servicebase" ]
                    }
                }
            }
        }
    /]

[/#macro]
