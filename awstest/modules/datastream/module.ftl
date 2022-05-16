[#ftl]

[@addModule
    name="datastream"
    description="Testing module for the aws datastream component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_datastream  ]

    [#-- Base --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "datastreambase":{
                            "Type": "datastream",
                            "deployment:Unit": "aws-datastream",
                            "Profiles" : {
                                "Testing" : [ "datastreambase" ]
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "datastreambase" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "Stream" : {
                                    "Name" : "datastreamXappXdatastreambase",
                                    "Type" : "AWS::Kinesis::Stream"
                                }
                            },
                            "Output" : [
                                "datastreamXappXdatastreambase",
                                "datastreamXappXdatastreambaseXarn"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "OnDemand_ProvisioningMode" : {
                                    "Path"  : "Resources.datastreamXappXdatastreambase.Properties.StreamModeDetails.StreamMode",
                                    "Value" : "ON_DEMAND"
                                },
                                "RetentionPeriod" : {
                                    "Path"  : "Resources.datastreamXappXdatastreambase.Properties.RetentionPeriodHours",
                                    "Value" : (30 * 24)
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "datastreambase" : {
                    "datastream" : {
                        "TestCases" : [ "datastreambase" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]

[/#macro]
