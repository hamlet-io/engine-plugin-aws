[#ftl]

[@addModule
    name="correspondent"
    description="Testing module for the aws correspondent component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_correspondent ]

    [#-- base template generation --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "mgmt" : {
                    "Components" : {
                        "correspondentbase" : {
                            "Type": "correspondent",
                            "deployment:Unit": "aws-correspondent",
                            "Profiles" : {
                                "Testing" : ["correspondentbase"]
                            },
                            "Name" : "pinpoint"
                        }
                    }
                }
            },
            "TestCases" : {
                "correspondentbase" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "correspondent" : {
                                    "Name" : "pinpointXmgmtXcorrespondentbase",
                                    "Type" : "AWS::Pinpoint::App"
                                }
                            },
                            "Output" : [
                                "pinpointXmgmtXcorrespondentbase",
                                "pinpointXmgmtXcorrespondentbaseXarn"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "correspondentbase" : {
                    "correspondent" : {
                        "TestCases" : [ "correspondentbase" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]

[/#macro]
