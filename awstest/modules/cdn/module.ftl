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
                                "cfXwebXcdnXv1" : {
                                    "Name" : "cfXwebXcdnXv1",
                                    "Type" : "AWS::CloudFront::Distribution"
                                }
                            },
                            "Output" : [
                                "cfXwebXcdnXv1Xdns",
                                "cfXwebXcdnXv1"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "CDNtags" : {
                                    "Path"  : "Resources.cfXwebXcdnXv1.Properties.Tags[10].Value",
                                    "Value" : "mockedup-integration-web-cdn-v1"
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
        stackOutputs=[ { "cfXwebXcdnspabase": "" } ]
    /]

[/#macro]
