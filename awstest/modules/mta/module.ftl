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
                        "mtabase_out" : {
                            "Type": "mta",
                            "deployment:Unit" : "aws-mta",
                            "Profiles" : {
                                "Testing" : [ "mtabase_out" ]
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
                                            "Component": "mtaout_topic",
                                            "Instance": "",
                                            "Version": ""
                                        }
                                    }
                                }
                            }
                        },
                        "mtaout_topic" : {
                            "Type" : "topic",
                            "deployment:Unit" : "aws-mta",
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
                "mtabase_out" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "ConfigurationSet" : {
                                    "Name" : "sesconfigsetXappXmtabaseXoutXtransmissions",
                                    "Type" : "AWS::SES::ConfigurationSet"
                                }
                            },
                            "Output" : [
                                "sesconfigsetXappXmtabaseXoutXtransmissionsXname"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "mtabase_out" : {
                    "mta" : {
                        "TestCases" : [ "mtabase_out" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]
[/#macro]
