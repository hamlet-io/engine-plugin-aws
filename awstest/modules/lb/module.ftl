[#ftl]

[@addModule
    name="lb"
    description="Testing module for the aws lb component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_lb  ]

    [#-- HTTPS Load Balancer --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "elb" : {
                    "Components" : {
                        "httpslb" : {
                            "LB" : {
                                "Instances" : {
                                    "default" : {
                                        "DeploymentUnits" : ["aws-lb-app-https"]
                                    }
                                },
                                "Engine" : "application",
                                "Logs" : true,
                                "Profiles" : {
                                    "Testing" : [ "Component" ]
                                },
                                "PortMappings" : {
                                    "https" : {
                                        "IPAddressGroups" : ["_global"],
                                        "Priority" : 500,
                                        "HostFilter" : true,
                                        "Certificate" : {
                                            "IncludeInHost" : {
                                                "Product" : false,
                                                "Environment" : true,
                                                "Segment" : false,
                                                "Tier" : false,
                                                "Component" : false,
                                                "Instance" : true,
                                                "Version" : false,
                                                "Host" : true
                                            },
                                            "Host" : "test"
                                        }
                                    },
                                    "httpredirect" : {
                                        "IPAddressGroups" : ["_global"],
                                        "Certificate" : {
                                            "IncludeInHost" : {
                                                "Product" : false,
                                                "Environment" : true,
                                                "Segment" : false,
                                                "Tier" : false,
                                                "Component" : false,
                                                "Instance" : true,
                                                "Version" : false,
                                                "Host" : true
                                            },
                                            "Host" : "test"
                                        },
                                        "HostFilter" : true,
                                        "Redirect" : {}
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "httpslb" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "httpListenerRule" : {
                                    "Name" : "listenerRuleXelbXhttpslbXhttpX100",
                                    "Type" : "AWS::ElasticLoadBalancingV2::ListenerRule"
                                },
                                "httpListener" : {
                                    "Name" : "listenerXelbXhttpslbXhttps",
                                    "Type" : "AWS::ElasticLoadBalancingV2::Listener"
                                },
                                "loadBalancer" : {
                                    "Name" : "albXelbXhttpslb",
                                    "Type" : "AWS::ElasticLoadBalancingV2::LoadBalancer"
                                }
                            },
                            "Output" : [
                                "securityGroupXlistenerXelbXhttpslbXhttps",
                                "listenerRuleXelbXhttpslbXhttpsX500",
                                "tgXdefaultXelbXhttpslbXhttps"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "LBName" : {
                                    "Path"  : "Resources.albXelbXhttpslb.Properties.Name",
                                    "Value" : "mockedup-int-elb-httpslb"
                                },
                                "HTTPCondition" : {
                                    "Path" : "Resources.listenerRuleXelbXhttpslbXhttpX100.Properties.Conditions[1]",
                                    "Value" : {
                                        "Field": "host-header",
                                        "Values": [
                                            "test-integration.mock.local"
                                        ]
                                    }
                                },
                                "HTTPAction" : {
                                    "Path" : "Resources.listenerRuleXelbXhttpslbXhttpX100.Properties.Actions[0]",
                                    "Value" : {
                                        "Type": "redirect",
                                        "RedirectConfig": {
                                            "Protocol": "HTTPS",
                                            "Port": "443",
                                            "Host": "#\{host}",
                                            "Path": "/#\{path}",
                                            "Query": "#\{query}",
                                            "StatusCode": "HTTP_301"
                                        }
                                    }
                                },
                                "HTTPCondition" : {
                                    "Path" : "Resources.listenerRuleXelbXhttpslbXhttpsX500.Properties.Conditions[1]",
                                    "Value" : {
                                        "Field": "host-header",
                                        "Values": [
                                            "test-integration.mock.local"
                                        ]
                                    }
                                },
                                "HTTPSAction" : {
                                    "Path" : "Resources.listenerRuleXelbXhttpslbXhttpsX500.Properties.Actions[0].Type",
                                    "Value" : "forward"
                                }
                            },
                            "Length" : {
                                "listenerActions" : {
                                    "Path" : "Resources.listenerRuleXelbXhttpslbXhttpX100.Properties.Actions",
                                    "Count" : 1
                                }
                            },
                            "NotEmpty" : [
                                "Resources.listenerRuleXelbXhttpslbXhttpX100.Properties.Priority"
                            ]
                        }
                    }
                },
                "validation" : {
                    "OutputSuffix" : "template.json",
                    "Tools" : {
                        "CFNLint" : true,
                        "CFNNag" : false
                    }
                }
            },
            "TestProfiles" : {
                "Component" : {
                    "lb" : {
                        "TestCases" : [ "httpslb", "validation" ]
                    }
                }
            }
        }
    /]
[/#macro]
