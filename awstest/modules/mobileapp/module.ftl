[#ftl]

[@addModule
    name="mobileapp"
    description="Testing module for the aws hosting of mobile app builds"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_mobileapp  ]

    [#-- Mobile App --]
    [@loadModule
        settingSets=[
            {
                "Type" : "Settings",
                "Scope" : "Accounts",
                "Namespace" : "mockacct-shared",
                "Settings" : {
                    "Registries": {
                        "scripts": {
                            "EndPoint": "account-registry-abc123",
                            "Prefix": "scripts/"
                        }
                    }
                }
            },
            {
                "Type" : "Builds",
                "Scope" : "Products",
                "Namespace" : "mockedup-integration-aws-mobileapp-base",
                "Settings" : {
                    "COMMIT" : "123456789#MockCommit#",
                    "FORMATS" : ["scripts"]
                }
            }
        ]
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "mobileappbase" : {
                            "mobileapp" : {
                                "Instances" : {
                                    "default" : {
                                        "DeploymentUnits" : ["aws-mobileapp-base"]
                                    }
                                },
                                "Profiles" : {
                                    "Testing" : [ "mobileappbase" ]
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "mobileappbase" : {
                    "OutputSuffix" : "config.json",
                    "Structural" : {
                        "JSON" : {
                            "Match" : {
                                "BuildFormats" : {
                                    "Path"  : "BuildConfig.APP_BUILD_FORMATS",
                                    "Value" : "ios,android"
                                },
                                "BUILD_REFERENCE" : {
                                    "Path" : "BuildConfig.BUILD_REFERENCE]",
                                    "Value" : "123456789#MockCommit#"
                                },
                                "RELEASE_CHANNEL" : {
                                    "Path" : "BuildConfig.RELEASE_CHANNEL",
                                    "Value" : "integration"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "mobileappbase" : {
                    "mobileapp" : {
                        "TestCases" : [ "mobileappbase" ]
                    }
                }
            }
        }
    /]
[/#macro]
