[#ftl]

[@addModule
    name="es"
    description="Testing module for the aws cache component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_es  ]

    [#-- Base --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "esbase": {
                            "Type": "es",
                            "deployment:Unit": "aws-es",
                            "Profiles" : {
                                "Testing" : [ "esbase" ]
                            },
                            "Version" : "7.1",
                            "IPAddressGroups" : [ "_localnet" ]
                        }
                    }
                }
            },
            "TestCases" : {
                "esbase" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "esDomain" : {
                                    "Name" : "esXappXesbase",
                                    "Type" : "AWS::Elasticsearch::Domain"
                                },
                                "lg" : {
                                    "Name" : "lgXappXesbase",
                                    "Type" : "AWS::Logs::LogGroup"
                                },
                                "snapShotRole" : {
                                    "Name" : "roleXesXappXesbaseXsnapshotStore",
                                    "Type" : "AWS::IAM::Role"
                                }
                            },
                            "Output" : [
                                "esXappXesbaseXdns",
                                "esXappXesbaseXarn"
                            ]
                        },
                        "JSON": {
                            "Match": {
                                "versionUpgradesEnabled" : {
                                    "Path"  : "Resources.esXappXesbase.UpdatePolicy.EnableVersionUpgrade",
                                    "Value" : true
                                },
                                "storageSizeDefined" : {
                                    "Path"  : "Resources.esXappXesbase.Properties.EBSOptions.VolumeSize",
                                    "Value" : 100
                                },
                                "errorLoggingEnabled" : {
                                    "Path": "Resources.esXappXesbase.Properties.LogPublishingOptions.ES_APPLICATION_LOGS.Enabled",
                                    "Value" : true
                                }
                            }
                        }
                    }
                }
            },
            "Storage": {
                "default": {
                    "es": {
                        "Volumes" : {
                            "data": {
                                "Size" : 100
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "esbase" : {
                    "es" : {
                        "TestCases" : [ "esbase" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
        stackOutputs=[
            {
                "Account" : "0123456789",
                "Region" : "mock-region-1",
                "DeploymentUnit" : "account-es",
                "logpolicyXaccountXes": "account-es"
            }
        ]
    /]

    [#-- Custom Endpoint --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "eshostname": {
                            "Type": "es",
                            "deployment:Unit": "aws-es",
                            "Profiles" : {
                                "Testing" : [ "eshostname" ]
                            },
                            "Version" : "7.1",
                            "IPAddressGroups" : [ "_localnet" ],
                            "Certificate" : {}
                        }
                    }
                }
            },
            "TestCases" : {
                "eshostname" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "esDomain" : {
                                    "Name" : "esXappXeshostname",
                                    "Type" : "AWS::Elasticsearch::Domain"
                                }
                            },
                            "Output" : [
                                "esXappXesbaseXdns"
                            ]
                        },
                        "JSON": {
                            "Match": {
                                "customEndpointEnabled" : {
                                    "Path"  : "Resources.esXappXeshostname.Properties.DomainEndpointOptions.CustomEndpointEnabled",
                                    "Value" : true
                                }
                            }
                        }
                    }
                }
            },
            "Storage": {
                "default": {
                    "es": {
                        "Volumes" : {
                            "data": {
                                "Size" : 100
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "esbase" : {
                    "es" : {
                        "TestCases" : [ "esbase" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                },
                "eshostname" : {
                    "es" : {
                        "TestCases" : [ "eshostname" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
        stackOutputs=[
            {
                "Account" : "0123456789",
                "Region" : "mock-region-1",
                "DeploymentUnit" : "account-es",
                "logpolicyXaccountXes": "account-es"
            }
        ]
    /]


[/#macro]
