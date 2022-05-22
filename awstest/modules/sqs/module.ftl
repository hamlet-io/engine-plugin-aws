[#ftl]

[@addModule
    name="sqs"
    description="Testing module for the aws sqs component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_sqs  ]

    [#-- Base sqs --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "sqsbase" : {
                            "Type": "sqs",
                            "deployment:Unit" : "aws-sqs",
                            "Profiles" : {
                                "Testing" : [ "sqsbase" ]
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "sqsbase" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "sqs" : {
                                    "Name" : "sqsXappXsqsbase",
                                    "Type" : "AWS::SQS::Queue"
                                }
                            },
                            "Output" : [
                                "sqsXappXsqsbaseXname",
                                "sqsXappXsqsbaseXurl",
                                "sqsXappXsqsbaseXarn"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "TagName" : {
                                    "Path"  : "Resources.sqsXappXsqsbase.Properties.Tags[0].Value",
                                    "Value" : "mockedup-integration-application-sqsbase"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "sqsbase" : {
                    "sqs" : {
                        "TestCases" : [ "sqsbase" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]
[/#macro]
