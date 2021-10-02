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
                            "sqs" : {
                                "Profiles" : {
                                    "Testing" : [ "sqsbase" ]
                                },
                                "deployment:Unit" : "aws-sqs-base",
                                "Instances" : {
                                    "default" : {}
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "sqsbase" : {
                    "OutputSuffix" : "template.json",
                    "Tools" : {
                       "cfn-lint" : {}
                    },
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
                                    "Path"  : "Resources.sqsXappXsqsbase.Properties.Tags[10].Value",
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
                    }
                }
            }
        }
    /]
[/#macro]
