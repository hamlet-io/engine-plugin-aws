[#ftl]

[@addModule
    name="cdn"
    description="Testing module for the aws cdn component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_cdn ]


    [@loadModule
        blueprint={
            "PlacementProfiles": {
                "cdn": {
                    "default": {
                        "Provider": "aws",
                        "Region": "us-east-1",
                        "DeploymentFramework": "cf"
                    }
                }
            }
        }
    /]

    [#-- Base setup --]
    [@loadModule
        settingSets=[
            {
                "Type" : "Builds",
                "Scope" : "Products",
                "Namespace" : "mockedup-integration-web-cdnbase_spa",
                "Settings" : {
                    "COMMIT" : "123456789#MockCommit#"
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
                                    "Path"  : "Resources.cfXwebXcdnbase.Properties.Tags[0].Value",
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

    [#-- Separate Origin --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "web" : {
                    "Components" : {
                        "cdnorigin": {
                            "Type": "cdn",
                            "deployment:Unit": "aws-cdn",
                            "Routes" : {
                                "default" : {
                                    "PathPattern": "_default",
                                    "OriginSource": "CDN",
                                    "OriginSource:CDN": {
                                        "Id": "lb"
                                    }
                                },
                                "static": {
                                    "PathPattern" : "static/*",
                                    "OriginSource" : "CDN",
                                    "OriginSource:CDN" : {
                                        "Id": "lb"
                                    },
                                    "RequestForwarding": {
                                        "AdditionalHeaders" : {
                                            "X-Anon-Content" : {
                                                "Value": "true"
                                            }
                                        }
                                    }
                                }
                            },
                            "Origins" : {
                                "lb" : {
                                    "Link" : {
                                        "Tier" : "web",
                                        "Component" : "cdnoriginlb",
                                        "SubComponent" : "https"
                                    }
                                }
                            },
                            "Profiles" : {
                                "Testing" : [ "cdnorigin" ]
                            }
                        },
                        "cdnoriginlb" : {
                            "Type" : "lb",
                            "deployment:Unit" : "aws-cdn",
                            "Engine" : "application",
                            "PortMappings" : {
                                "https": {
                                    "Mapping" : "https"
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "cdnorigin" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "cfXwebXcdnorigin" : {
                                    "Name" : "cfXwebXcdnorigin",
                                    "Type" : "AWS::CloudFront::Distribution"
                                }
                            },
                            "Output" : [
                                "cfXwebXcdnoriginXdns",
                                "cfXwebXcdnorigin"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "SplitOrigin" : {
                                    "Path" : "Resources.cfXwebXcdnorigin.Properties.DistributionConfig.Origins[0].Id",
                                    "Value" : "cforiginXwebXcdnoriginXlbXcdnorigin"
                                },
                                "CDNtags" : {
                                    "Path"  : "Resources.cfXwebXcdnorigin.Properties.Tags[0].Value",
                                    "Value" : "mockedup-integration-web-cdnorigin"
                                }
                            },
                            "Length" : {
                                "Origins" : {
                                    "Path" : "Resources.cfXwebXcdnorigin.Properties.DistributionConfig.Origins",
                                    "Count" : 1
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "cdnorigin" : {
                    "cdn" : {
                        "TestCases" : [ "cdnorigin" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]

    [#-- Response Policy --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "web" : {
                    "Components" : {
                        "cdnheaderresponse": {
                            "Type": "cdn",
                            "deployment:Unit": "aws-cdn",
                            "Routes" : {
                                "default" : {
                                    "PathPattern": "_default",
                                    "OriginSource": "Route",
                                    "OriginSource:Route": {
                                        "Link" : {
                                            "Tier" : "web",
                                            "Component" : "cdnheaderresponselb",
                                            "SubComponent" : "https"
                                        }
                                    },
                                    "ResponsePolicy" : {
                                        "Id" : "hsts"
                                    }
                                }
                            },
                            "ResponsePolicies" :{
                                "hsts" : {
                                    "HeaderInjection" : {
                                        "StrictTransportSecurity" : {
                                            "Enabled": true
                                        }
                                    }
                                }
                            },
                            "Profiles" : {
                                "Testing" : [ "cdnheaderresponse" ]
                            }
                        },
                        "cdnheaderresponselb" : {
                            "Type" : "lb",
                            "deployment:Unit" : "aws-cdn",
                            "Engine" : "application",
                            "PortMappings" : {
                                "https": {
                                    "Mapping" : "https"
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "cdnheaderresponse" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "cfXwebXcdnheaderresponse" : {
                                    "Name" : "cfXwebXcdnheaderresponse",
                                    "Type" : "AWS::CloudFront::Distribution"
                                },
                                "cfresponseheaderspolicyXwebXcdnheaderresponseXhsts" : {
                                    "Name" : "cfresponseheaderspolicyXwebXcdnheaderresponseXhsts",
                                    "Type" : "AWS::CloudFront::ResponseHeadersPolicy"
                                }
                            },
                            "Output" : [
                                "cfXwebXcdnheaderresponseXdns",
                                "cfXwebXcdnheaderresponse"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "HSTSDontOverride" : {
                                    "Path" : "Resources.cfresponseheaderspolicyXwebXcdnheaderresponseXhsts.Properties.ResponseHeadersPolicyConfig.SecurityHeadersConfig.StrictTransportSecurity.Override",
                                    "Value" : false
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "cdnheaderresponse" : {
                    "cdn" : {
                        "TestCases" : [ "cdnheaderresponse" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]

    [#-- Cache Policy --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "web" : {
                    "Components" : {
                        "cdncachepolicy": {
                            "Type": "cdn",
                            "deployment:Unit": "aws-cdn",
                            "Routes" : {
                                "default" : {
                                    "PathPattern": "_default",
                                    "OriginSource": "Route",
                                    "OriginSource:Route": {
                                        "Link" : {
                                            "Tier" : "web",
                                            "Component" : "cdncachepolicylb",
                                            "SubComponent" : "https"
                                        }
                                    },
                                    "CachePolicy" : "Custom",
                                    "CachePolicy:Custom": {
                                        "Id" : "CacheAll"
                                    }
                                }
                            },
                            "CachePolicies" :{
                                "CacheAll" : {
                                    "Headers" : [],
                                    "Methods" : ["GET", "HEAD", "OPTIONS"],
                                    "QueryParams": [],
                                    "Cookies": [],
                                    "TTL" : {
                                        "Minimum" : 86400,
                                        "Maximum" : 86400,
                                        "Default" : 86400
                                    }
                                }
                            },
                            "Profiles" : {
                                "Testing" : [ "cdncachepolicy" ]
                            }
                        },
                        "cdncachepolicylb" : {
                            "Type" : "lb",
                            "deployment:Unit" : "aws-cdn",
                            "Engine" : "application",
                            "PortMappings" : {
                                "https": {
                                    "Mapping" : "https"
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "cdncachepolicy" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "cfXwebXcdncachepolicy" : {
                                    "Name" : "cfXwebXcdnheaderresponse",
                                    "Type" : "AWS::CloudFront::Distribution"
                                },
                                "cfcachepolicyXwebXcdncachepolicyXCacheAll" : {
                                    "Name" : "cfcachepolicyXwebXcdncachepolicyXCacheAll",
                                    "Type" : "AWS::CloudFront::CachePolicy"
                                }
                            },
                            "Output" : [
                                "cfXwebXcdncachepolicyXdns",
                                "cfXwebXcdncachepolicy"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "HSTSDontOverride" : {
                                    "Path" : "Resources.cfcachepolicyXwebXcdncachepolicyXCacheAll.Properties.CachePolicyConfig.MinTTL",
                                    "Value" : 86400
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "cdncachepolicy" : {
                    "cdn" : {
                        "TestCases" : [ "cdncachepolicy" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]

    [#-- WAF --]
    [#-- Disabled until we can support changing regions in modules --]
    [@loadModule
        settingSets=[
            {
                "Type" : "Builds",
                "Scope" : "Products",
                "Namespace" : "mockedup-integration-web-cdnbase_spa",
                "Settings" : {
                    "COMMIT" : "123456789#MockCommit#"
                }
            }
        ]
        blueprint={
            "Tiers" : {
                "web" : {
                    "Components" : {
                        "cdnwaf": {
                            "Type": "cdn",
                            "Enabled": false,
                            "deployment:Unit": "aws-cdn",
                            "Routes" : {
                                "default" : {
                                    "PathPattern" : "_default",
                                    "Origin" : {
                                        "Link" : {
                                            "Tier" : "web",
                                            "Component" : "cdnwaf_spa"
                                        }
                                    }
                                }
                            },
                            "WAF" : {
                                "Enabled": true
                            },
                            "Profiles" : {
                                "Testing" : [ "cdnwaf" ],
                                "Placement" : "cdn"
                            }
                        },
                        "cdnwaf_spa": {
                            "Type": "spa",
                            "Enabled": false,
                            "deployment:Unit": "aws-cdn",
                            "Links": {
                                "cdn": {
                                    "Tier": "web",
                                    "Component": "cdnwaf",
                                    "Route": "default",
                                    "Direction": "inbound"
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "cdnwaf" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "cfXwebXcdnwaf" : {
                                    "Name" : "cfXwebXcdnwaf",
                                    "Type" : "AWS::CloudFront::Distribution"
                                },
                                "WafACL": {
                                    "Name": "wafv2AclXcfXwebXcdnwaf",
                                    "Type": "AWS::WAFv2::WebACL"
                                },
                                "WafAssoc" : {
                                    "Name": "wafv2AssocXcfXwebXcdnwaf",
                                    "Type" : "AWS::WAFv2::WebACLAssociation"
                                }
                            },
                            "Output" : [
                                "cfXwebXcdnwafXdns",
                                "cfXwebXcdnwaf",
                                "wafv2AclXcfXwebXcdnwaf"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "WafDepends" : {
                                    "Path"  : "Resources.wafv2AssocXcfXwebXcdnwaf.DependsOn[0]",
                                    "Value" : "cfXwebXcdnwaf"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "cdnwaf" : {
                    "cdn" : {
                        "TestCases" : [ "cdnwaf" ]
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
                "Region" : "us-east-1",
                "DeploymentUnit" : "aws-cdn",
                "cfXwebXcdnwaf": "abc123def"
            }
        ]
    /]
[/#macro]
