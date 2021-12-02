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
                            "Hostname" : {},
                            "Direction" : "send",
                            "Rules" : {
                                "transmissions" : {
                                    "Enabled" : true,
                                    "Order" : 1,
                                    "Conditions" : {
                                        "Senders" : [ "*" ]
                                    },
                                    "EventTypes" : ["delivery"],
                                    "Action" : "log",
                                    "Links" : {
                                        "topic": {
                                            "Tier": "app",
                                            "Component": "mtatopic",
                                            "Instance": "",
                                            "Version": ""
                                        }
                                    }
                                }
                            }
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
                                "ConfigurationSet" : {
                                    "Name" : "sesconfigsetXappXmtaoutbaseXtransmissions",
                                    "Type" : "AWS::SES::ConfigurationSet"
                                }
                            },
                            "Output" : [
                                "sesconfigsetXappXmtaoutbaseXtransmissionsXname"
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
