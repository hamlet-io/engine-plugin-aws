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
                                "Profiles" : {
                                    "Testing" : [ "userpoolbase" ]
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
                        },
                        "JSON" : {
                            "NotEmpty" : [
                                "Resources.userpooldomainXappXuserpoolbase.Properties.UserPoolId",
                                "Resources.userpooldomainXappXuserpoolbase.Properties.Domain"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "userpoolbase" : {
                    "userpool" : {
                        "TestCases" : [ "userpoolbase" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]

[/#macro]
