[#ftl]

[@addModule
    name="cdn"
    description="Testing module for the aws cdn component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_cdn ]

    [#-- Base database setup --]
    [@loadModule
        settingSets=[
            {
                "Type" : "Settings",
                "Scope" : "Accounts",
                "Namespace" : "mockacct-shared",
                "Settings" : {
                    "Registries": {
                        "spa": {
                            "EndPoint": "account-registry-abc123",
                            "Prefix": "spa/"
                        }
                    }
                }
            },
            {
                "Type" : "Builds",
                "Scope" : "Products",
                "Namespace" : "mockedup-integration-web-cdnbase_spa",
                "Settings" : {
                    "COMMIT" : "123456789#MockCommit#",
                    "FORMATS" : [ "spa" ]
                }
            }
        ]
        blueprint={
            "Tiers" : {
                "web" : {
                    "Components" : {
                        "cdnbase": {
                            "Type": "cdn",
                            "deployment:Unit": "aws-cdn",
                            "Routes" : {
                                "default" : {
                                    "PathPattern" : "_default",
                                    "Origin" : {
                                        "Link" : {
                                            "Tier" : "web",
                                            "Component" : "cdnbase_spa"
                                        }
                                    }
                                }
                            },
                            "Profiles" : {
                                "Testing" : [ "cdnbase" ]
                            }
                        },
                        "cdnbase_spa": {
                            "Type": "spa",
                            "deployment:Unit": "aws-cdn",
                            "Links": {
                                "cdn": {
                                    "Tier": "web",
                                    "Component": "cdnbase",
                                    "Route": "default",
                                    "Direction": "inbound"
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "cdnbase" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "cfXwebXcdnbase" : {
                                    "Name" : "cfXwebXcdnbase",
                                    "Type" : "AWS::CloudFront::Distribution"
                                }
                            },
                            "Output" : [
                                "cfXwebXcdnbaseXdns",
                                "cfXwebXcdnbase"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "CDNtags" : {
                                    "Path"  : "Resources.cfXwebXcdnbase.Properties.Tags[10].Value",
                                    "Value" : "mockedup-integration-web-cdnbase"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "cdnbase" : {
                    "cdn" : {
                        "TestCases" : [ "cdnbase" ]
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
                "DeploymentUnit" : "aws-cdn",
                "cfXwebXcdnbase": "abc123def"
            }
        ]
    /]
[/#macro]
