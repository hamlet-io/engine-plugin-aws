[#ftl]

[@addModule
    name="topic"
    description="Testing module for the aws sns topic component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_topic  ]

    [#-- HTTPS Load Balancer --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "topicbase" : {
                            "Type": "topic",
                            "deployment:Unit": "aws-topic",
                            "Profiles" : {
                                "Testing" : [ "topicbase" ]
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "topicbase" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "topicbase" : {
                                    "Name" : "snstopicXappXtopicbase",
                                    "Type" : "AWS::SNS::Topic"
                                }
                            }
                        },
                        "JSON": {
                            "Match" : {
                                "TagName" : {
                                    "Path"  : "Resources.snstopicXappXtopicbase.Properties.Tags[10].Value",
                                    "Value" : "mockedup-integration-application-topicbase"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "topicbase" : {
                    "topic" : {
                        "TestCases" : [ "topicbase" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]
[/#macro]
