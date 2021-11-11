[#ftl]

[@addModule
    name="mta"
    description="Testing module for the aws mta component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]


[#macro awstest_module_mta ]

    [#-- Base outbound setup --]
    [@loadModule
        settingSets=[
            {
                "Type" : "Settings",
                "Scope" : "Products",
                "Namespace" : "mockedup-integration-aws-mta-out",
                "Settings" : {
                    "MASTER_USERNAME" : "testUser",
                    "MASTER_PASSWORD" : "testPassword"
                }
            }
        ]
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "mtaoutbase" : {
                            "Type": "mta",
                            "deployment:Unit" : "aws-mta-out-base",
                                "Profiles" : {
                                    "Testing" : [ "mtaoutbase" ]
                                },
                            "Direction" : "send",
                            "Rules" : {
                                "transmissions" : {
                                    "Enabled" : true,
                                    "Order" : 1,
                                    "Conditions" : {
                                        "EventTypes" : ["delivery"]
                                    },
                                    "Action" : "forward",
                                    "Links" : {
                                        "topic": {
                                            "Tier": "app",
                                            "Component": "mtatopic",
                                            "Instance": "",
                                            "Version": ""
                                        }
                                    }
                                }
                            },
                            "Certificate" : {}
                        },
                        "mtatopic" : {
                            "Type" : "topic",
                            "deployment:Unit" : "aws-mta-topic",
                            "Subscriptions" : {
                                "landingqueue" : {
                                    "Links" : {
                                        "mta" : {
                                            "Enabled" : false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "mtaoutbase" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "mtaOutInstance" : {
                                    "Name" : "sesconfigset",
                                    "Type" : "AWS::SES::ConfigurationSet"
                                }
                            },
                            "Output" : [
                                "sesconfigsetXname"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "mtaoutbase" : {
                    "mta" : {
                        "TestCases" : [ "mtaoutbase" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]
[/#macro]
