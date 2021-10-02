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
                                        "HostHeaderConfig": {
                                            "Values": [
                                                "test-integration.mock.local"
                                            ]
                                        }
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
                "lint" : {
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
                        "TestCases" : [ "httpslb", "lint" ]
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
                                    "Value" :           {
                                        "Field": "host-header",
                                        "HostHeaderConfig": {
                                            "Values": [
                                                "test-integration.mock.local"
                                            ]
                                        }
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
                "lint" : {
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
                        "TestCases" : [ "httplb", "httplbfixeddefault", "lint" ]
                    }
                }
            }
        }
    /]

    [#-- Condition Checking --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "elb" : {
                    "Components" : {
                        "conditionapplb" : {
                            "LB" : {
                                "Instances" : {
                                    "default" : {
                                        "DeploymentUnits" : ["aws-lb-app-condition"]
                                    }
                                },
                                "Engine" : "application",
                                "Logs" : true,
                                "Profiles" : {
                                    "Testing" : [ "conditionapplb" ]
                                },
                                "PortMappings" : {
                                    "http" : {
                                        "IPAddressGroups" : ["_global"],
                                        "Conditions" : {
                                            "httpHeader" : {
                                                "Type" : "httpHeader",
                                                "type:httpHeader" : {
                                                    "HeaderName" : "TestHeader",
                                                    "HeaderValues" : [ "testValue1" ]
                                                }
                                            },
                                            "httpRequestMethod" : {
                                                "Type" : "httpRequestMethod",
                                                "type:httpRequestMethod" : {
                                                    "Methods" : [ "GET", "HEAD" ]
                                                }
                                            },
                                            "httpQueryString" : {
                                                "Type" : "httpQueryString",
                                                "type:httpQueryString" : {
                                                    "query" : {
                                                        "Key" : "query",
                                                        "Value" : "queryValue1"
                                                    }
                                                }
                                            },
                                            "SourceIP" : {
                                                "Type" : "SourceIP",
                                                "type:SourceIP" : {
                                                    "IPAddressGroups" : [ "_localnet" ]
                                                }
                                            }
                                        },
                                        "Forward" : {}
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "conditionapplb" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "httpListenerRule" : {
                                    "Name" : "listenerRuleXelbXconditionapplbXhttpX100",
                                    "Type" : "AWS::ElasticLoadBalancingV2::ListenerRule"
                                },
                                "httpListener" : {
                                    "Name" : "listenerXelbXconditionapplbXhttp",
                                    "Type" : "AWS::ElasticLoadBalancingV2::Listener"
                                },
                                "loadBalancer" : {
                                    "Name" : "albXelbXconditionapplb",
                                    "Type" : "AWS::ElasticLoadBalancingV2::LoadBalancer"
                                }
                            },
                            "Output" : [
                                "listenerXelbXconditionapplbXhttp"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "LBName" : {
                                    "Path"  : "Resources.albXelbXconditionapplb.Properties.Name",
                                    "Value" : "mockedup-int-elb-conditionapplb"
                                },
                                "HTTPConditionDefaultPath" : {
                                    "Path" : "Resources.listenerRuleXelbXconditionapplbXhttpX100.Properties.Conditions[0]",
                                    "Value" : {
                                        "Field": "path-pattern",
                                        "PathPatternConfig": {
                                            "Values": [
                                                "*"
                                            ]
                                        }
                                    }
                                },
                                "HTTPConditionHttpHeader" : {
                                    "Path" : "Resources.listenerRuleXelbXconditionapplbXhttpX100.Properties.Conditions[1]",
                                    "Value" :           {
                                        "Field": "http-header",
                                        "HttpHeaderConfig": {
                                        "Values": [
                                            "testValue1"
                                        ],
                                        "HttpHeaderName": "TestHeader"
                                        }
                                    }
                                },
                                "HTTPConditionRequestMethod" : {
                                    "Path" : "Resources.listenerRuleXelbXconditionapplbXhttpX100.Properties.Conditions[2]",
                                    "Value" : {
                                        "Field": "http-request-method",
                                        "HttpRequestMethodConfig": {
                                        "Values": [
                                            "GET",
                                            "HEAD"
                                        ]
                                        }
                                    }
                                },
                                "HTTPConditionSourceIP" : {
                                    "Path" : "Resources.listenerRuleXelbXconditionapplbXhttpX100.Properties.Conditions[4]",
                                    "Value" :           {
                                        "Field": "source-ip",
                                        "SourceIpConfig": {
                                            "Values": [
                                                "10.0.0.0/16"
                                            ]
                                        }
                                    }
                                },
                                "HTTPAction" : {
                                    "Path" : "Resources.listenerRuleXelbXconditionapplbXhttpX100.Properties.Actions[0]",
                                    "Value" : {
                                        "Type": "forward",
                                        "TargetGroupArn": "arn:aws:iam::123456789012:mock/tgXelbXconditionapplbXhttpXarn"
                                    }
                                }
                            },
                            "Length" : {
                                "listenerRuleConditions" : {
                                    "Path" : "Resources.listenerRuleXelbXconditionapplbXhttpX100.Properties.Conditions",
                                    "Count" : 5
                                }
                            },
                            "NotEmpty" : [
                                "Resources.listenerRuleXelbXconditionapplbXhttpX100.Properties.Priority"
                            ]
                        }
                    }
                },
                "lint" : {
                    "OutputSuffix" : "template.json",
                    "Tools" : {
                        "CFNLint" : true,
                        "CFNNag" : false
                    }
                }
            },
            "TestProfiles" : {
                "conditionapplb" : {
                    "lb" : {
                        "TestCases" : [ "conditionapplb", "lint" ]
                    }
                }
            }
        }
    /]
[/#macro]
