[#ftl]

[@addModule
    name="userpool"
    description="Testing module for the aws userpool component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]


[#macro awstest_module_userpool ]

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
                "Namespace" : "mockedup-integration-aws-userpool-base",
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
                        "userpoolbase" : {
                            "userpool" : {
                                "Instances" : {
                                    "default" : {
                                        "deployment:Unit" : "aws-userpool-base"
                                    }
                                },
                                "DefaultClient" : false,
                                "Schema" : {
                                    "email" : {
                                        "Required" : true
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "userpoolbase" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "userPool" : {
                                    "Name" : "userpoolXappXuserpoolbase",
                                    "Type" : "AWS::Cognito::UserPool"
                                }
                            },
                            "Output" : [
                                "userpoolXappXuserpoolbase",
                                "userpoolXappXuserpoolbaseXurl",
                                "userpoolXappXuserpoolbaseXarn",
                                "userpoolXappXuserpoolbaseXregion"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "userpoolbase" : {
                    "userpool" : {
                        "TestCases" : [ "userpoolbase" ]
                    }
                }
            }
        }
    /]

[/#macro]
