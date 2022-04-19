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
                            "Type": "lb",
                            "deployment:Unit": "aws-lb",
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
                                    "Name" : "lbXelbXhttpslb",
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
                                    "Path"  : "Resources.lbXelbXhttpslb.Properties.Name",
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
                }
            },
            "TestProfiles" : {
                "httpslb" : {
                    "lb" : {
                        "TestCases" : [ "httpslb" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
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
                            "Type": "lb",
                            "deployment:Unit": "aws-lb",
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
                                    "Name" : "lbXelbXhttplb",
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
                                    "Path"  : "Resources.lbXelbXhttplb.Properties.Name",
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
                                        "TargetGroupArn": {
                                            "Ref": "tgXelbXhttplbXhttp"
                                        }
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
                                    "Name" : "lbXelbXhttplb",
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
                                    "Path" : "Resources.listenerXelbXhttplbXhttp.Properties.LoadBalancerArn.Ref",
                                    "Value" : "lbXelbXhttplb"
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
                }
            },
            "TestProfiles" : {
                "httplb" : {
                    "lb" : {
                        "TestCases" : [ "httplb", "httplbfixeddefault" ]
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
                            "Type": "lb",
                            "deployment:Unit": "aws-lb",
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
                                    "Name" : "lbXelbXconditionapplb",
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
                                    "Path"  : "Resources.lbXelbXconditionapplb.Properties.Name",
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
                                        "TargetGroupArn": {
                                            "Ref": "tgXelbXconditionapplbXhttp"
                                        }
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
                }
            },
            "TestProfiles" : {
                "conditionapplb" : {
                    "lb" : {
                        "TestCases" : [ "conditionapplb" ]
                    }
                }
            }
        }
    /]

    [#-- NLB -> ALB --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "elb" : {
                    "Components" : {
                        "nlbalb_nlb" : {
                            "Type": "lb",
                            "deployment:Unit" : "aws-lb",
                            "Engine" : "network",
                            "Logs" : true,
                            "Profiles" : {
                                "Testing" : [ "nlbalb" ]
                            },
                            "PortMappings" : {
                                "http" : {
                                    "IPAddressGroups" : ["_global"],
                                    "Mapping" : "http-tcp",
                                    "Forward" : {
                                        "TargetType" : "aws:alb",
                                        "StaticEndpoints" : {
                                            "Links" : {
                                                "alb": {
                                                    "Tier" : "elb",
                                                    "Component" : "nlbalb_alb",
                                                    "SubComponent" : "http"
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        },
                        "nlbalb_alb" : {
                            "Type": "lb",
                            "deployment:Unit" : "aws-lb",
                            "Engine" : "application",
                            "Logs" : true,
                            "PortMappings" : {
                                "http" : {
                                    "Mapping" : "http",
                                    "IPAddressGroups" : ["_global"],
                                    "Forward" : {}
                                }
                            }
                        }
                    }
                }
            },
            "PortMappings" : {
                "http-tcp" : {
                    "Source" : "http-tcp",
                    "Destination" : "http-tcp"
                }
            },
            "Ports" : {
                "http-tcp": {
                    "IPProtocol" : "tcp",
                    "Protocol" : "TCP",
                    "Port" : 80,
                    "HealthCheck": {
                        "Protocol" : "HTTP",
                        "UnhealthyThreshold": "5",
                        "Timeout": "5",
                        "HealthyThreshold": "3",
                        "Configured": true,
                        "Interval": "30"
                    }
                }
            },
            "TestCases": {
                "nlbalb" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "httpTargetGroup" : {
                                    "Name" : "tgXdefaultXelbXnlbalbXnlbXhttpXtcp",
                                    "Type" : "AWS::ElasticLoadBalancingV2::TargetGroup"
                                },
                                "loadBalancer" : {
                                    "Name" : "lbXelbXnlbalbXnlb",
                                    "Type" : "AWS::ElasticLoadBalancingV2::LoadBalancer"
                                }
                            },
                            "Output" : [
                                "tgXdefaultXelbXnlbalbXnlbXhttpXtcp"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "LBName": {
                                    "Path": "Resources.lbXelbXnlbalbXnlb.Properties.Name",
                                    "Value": "mockedup-int-elb-nlbalb_nlb"
                                },
                                "ALBTypeTargetGroup": {
                                    "Path": "Resources.tgXdefaultXelbXnlbalbXnlbXhttpXtcp.Properties.TargetType",
                                    "Value": "alb"
                                },
                                "HealthCheckProtocol" : {
                                    "Path" : "Resources.tgXdefaultXelbXnlbalbXnlbXhttpXtcp.Properties.HealthCheckProtocol",
                                    "Value": "HTTP"
                                },
                                "Protocol" : {
                                    "Path" : "Resources.tgXdefaultXelbXnlbalbXnlbXhttpXtcp.Properties.Protocol",
                                    "Value": "TCP"
                                },
                                "ALBTarget": {
                                    "Path": "Resources.tgXdefaultXelbXnlbalbXnlbXhttpXtcp.Properties.Targets[0].Id.Ref",
                                    "Value": "lbXelbXnlbalbXalb"
                                }
                            },
                            "Length": {
                                "listenerRuleConditions": {
                                    "Path": "Resources.tgXdefaultXelbXnlbalbXnlbXhttpXtcp.Properties.Targets",
                                    "Count": 1
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles": {
                "nlbalb": {
                    "lb": {
                        "TestCases": [ "nlbalb" ]
                    }
                }
            }
        }
        stackOutputs=[
            {
                "Account" : "0123456789",
                "Region" : "mock-region-1",
                "DeploymentUnit" : "aws-lb",
                "lbXelbXnlbalbXalb" : "lbXelbXnlbalbXalb"
            }
        ]
    /]
[/#macro]
