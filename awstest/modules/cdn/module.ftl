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
                "Namespace" : "mockedup-integration-aws-cdn-spa-base",
                "Settings" : {
                    "COMMIT" : "123456789#MockCommit#",
                    "FORMATS" : [ "spa" ]
                }
            },
            {
                "Type" : "Settings",
                "Scope" : "Products",
                "Namespace" : "mockedup-integration-aws-cdn-base",
                "Settings" : {
                    "MASTER_USERNAME" : "testUser",
                    "MASTER_PASSWORD" : "testPassword"
                }
            }
        ]
        blueprint={
            "Tiers" : {
                "web" : {
                    "Components" : {
                        "cdnbase": {
                            "cdn": {
                                "Instances": {
                                    "default": {
                                        "DeploymentUnits": [ "aws-cdn-base" ]
                                    }
                                },
                                "Routes" : {
                                    "default" : {
                                        "PathPattern" : "_default",
                                        "Origin" : {
                                            "Link" : {
                                                "Tier" : "web",
                                                "Component" : "cdnspabase"
                                            }
                                        }
                                    }
                                },
                                "Profiles" : {
                                    "Testing" : [ "cdnbase" ]
                                }
                            }
                        },
                        "cdnspabase": {
                            "spa": {
                                "Instances": {
                                    "default": {
                                        "DeploymentUnits": [ "aws-cdn-spa-base" ]
                                    }
                                },
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
                }
            },
            "TestCases" : {
                "cdnbase" : {
                    "OutputSuffix" : "template.json",
                    "Tools" : {
                       "CFNLint" : true
                    },
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
                    }
                }
            }
        }
        stackOutputs=[
            {
                "Account" : "0123456789",
                "Region" : "mock-region-1",
                "DeploymentUnit" : "aws-cdn-spa-base",
                "cfXwebXcdnspabase": "hamlet:empty"
            }
        ]
    /]
[/#macro]
