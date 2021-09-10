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
                                    "Testing" : [ "httpslb" ]
                                },
                                "PortMappings" : {
                                    "https" : {
                                        "IPAddressGroups" : ["_global"],
                                        "Priority" : 500,
                                        "HostFilter" : true,
                                        "Hostname" : {
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
                                        "Hostname" : {
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
                                "tgXelbXhttpslbXhttpsXname"
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
                "httpslb" : {
                    "lb" : {
                        "TestCases" : [ "httpslb", "validation" ]
                    }
                }
            }
        }
    /]

    [#-- HTTP Load Balancer --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "elb" : {
                    "Components" : {
                        "httplb" : {
                            "LB" : {
                                "Instances" : {
                                    "default" : {
                                        "DeploymentUnits" : ["aws-lb-app-http"]
                                    }
                                },
                                "Engine" : "application",
                                "Logs" : true,
                                "Profiles" : {
                                    "Testing" : [ "httplb" ]
                                },
                                "PortMappings" : {
                                    "http" : {
                                        "IPAddressGroups" : ["_global"],
                                        "Hostname" : {
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
                                        "Priority" : 100,
                                        "HostFilter" : true,
                                        "Forward" : {}
                                    },
                                    "httpfixeddefault": {
                                        "IPAddressGroups" : ["_global"],
                                        "Mapping" : "http",
                                        "Priority" : "default",
                                        "Fixed" : {
                                            "Message" : "Fixed Response",
                                            "StatusCode" : "200",
                                            "ContentType" : "text/plain"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "httplb" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "httpListenerRule" : {
                                    "Name" : "listenerRuleXelbXhttplbXhttpX100",
                                    "Type" : "AWS::ElasticLoadBalancingV2::ListenerRule"
                                },
                                "httpListener" : {
                                    "Name" : "listenerXelbXhttplbXhttp",
                                    "Type" : "AWS::ElasticLoadBalancingV2::Listener"
                                },
                                "loadBalancer" : {
                                    "Name" : "albXelbXhttplb",
                                    "Type" : "AWS::ElasticLoadBalancingV2::LoadBalancer"
                                }
                            },
                            "Output" : [
                                "securityGroupXlistenerXelbXhttplbXhttp",
                                "listenerRuleXelbXhttplbXhttpX100",
                                "tgXelbXhttplbXhttpXname"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "LBName" : {
                                    "Path"  : "Resources.albXelbXhttplb.Properties.Name",
                                    "Value" : "mockedup-int-elb-httplb"
                                },
                                "HTTPCondition" : {
                                    "Path" : "Resources.listenerRuleXelbXhttplbXhttpX100.Properties.Conditions[1]",
                                    "Value" : {
                                        "Field": "host-header",
                                        "Values": [
                                            "test-integration.mock.local"
                                        ]
                                    }
                                },
                                "HTTPAction" : {
                                    "Path" : "Resources.listenerRuleXelbXhttplbXhttpX100.Properties.Actions[0]",
                                    "Value" : {
                                        "Type": "forward",
                                        "TargetGroupArn": "arn:aws:iam::123456789012:mock/tgXelbXhttplbXhttpXarn"
                                    }
                                }
                            },
                            "Length" : {
                                "listenerActions" : {
                                    "Path" : "Resources.listenerRuleXelbXhttplbXhttpX100.Properties.Actions",
                                    "Count" : 1
                                }
                            },
                            "NotEmpty" : [
                                "Resources.listenerRuleXelbXhttplbXhttpX100.Properties.Priority"
                            ]
                        }
                    }
                },
                "httplbfixeddefault" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "httpListener" : {
                                    "Name" : "listenerXelbXhttplbXhttp",
                                    "Type" : "AWS::ElasticLoadBalancingV2::Listener"
                                },
                                "loadBalancer" : {
                                    "Name" : "albXelbXhttplb",
                                    "Type" : "AWS::ElasticLoadBalancingV2::LoadBalancer"
                                }
                            }
                        },
                        "JSON" : {
                            "Match" : {
                                "HTTPFixedResponseAction" : {
                                    "Path" : "Resources.listenerXelbXhttplbXhttp.Properties.DefaultActions[0]",
                                    "Value" : {
                                        "Type": "fixed-response",
                                        "FixedResponseConfig": {
                                            "ContentType": "text/plain",
                                            "StatusCode": "200",
                                            "MessageBody": "Fixed Response"
                                        }
                                    }
                                },
                                "LoadBalancerLink" : {
                                    "Path" : "Resources.listenerXelbXhttplbXhttp.Properties.LoadBalancerArn",
                                    "Value" : "##MockOutputXalbXelbXhttplbX##"
                                }
                            },
                            "Length" : {
                                "listenerActions" : {
                                    "Path" : "Resources.listenerXelbXhttplbXhttp.Properties.DefaultActions",
                                    "Count" : 1
                                }
                            }
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
                "httplb" : {
                    "lb" : {
                        "TestCases" : [ "httplb", "httplbfixeddefault", "validation" ]
                    }
                }
            }
        }
    /]
[/#macro]
