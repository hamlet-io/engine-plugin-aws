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
                "Namespace" : "mockedup-integration-app-mobileappbase",
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
                            "Type": "mobileapp",
                            "deployment:Unit": "aws-mobileapp",
                            "Profiles" : {
                                "Testing" : [ "mobileappbase" ]
                            },
                            "BuildFormats:android" : {
                                "KeyStore" : {
                                    "Password" : "password123",
                                    "KeyAlias" : "my-key",
                                    "KeyPassword" : "password123"
                                }
                            },
                            "BuildFormats:ios" : {
                                "AppleTeamId" : "123456",
                                "TestFlight" : {
                                    "AppId": "APPL123",
                                    "Username" : "user1",
                                    "Password": "password123"
                                },
                                "DistributionCertificatePassword" : "password123"
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
                                    "Path" : "BuildConfig.BUILD_REFERENCE",
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
