[#ftl]

[@addModule
    name="logstore"
    description="Testing module for the aws logstore component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_logstore ]

    [#-- Base outbound setup --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "mgmt" : {
                    "Components" : {
                        "logstorebase" : {
                            "Type": "logstore",
                            "deployment:Unit" : "aws-logstore",
                            "Profiles" : {
                                "Testing" : [ "logstore_base" ]
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "logstore_base" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "ConfigurationSet" : {
                                    "Name" : "lgXmgmtXlogstorebase",
                                    "Type" : "AWS::Logs::LogGroup"
                                }
                            }
                        },
                        "JSON" : {
                            "Match" : {
                                "vpcCIDR" : {
                                    "Path"  : "Resources.lgXmgmtXlogstorebase.Properties.LogGroupName",
                                    "Value" : "/mockedup/integration/default/management/logstorebase"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "logstore_base" : {
                    "mta" : {
                        "TestCases" : [ "logstore_base" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]
[/#macro]
