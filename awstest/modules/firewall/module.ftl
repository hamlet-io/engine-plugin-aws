[#ftl]

[@addModule
    name="firewall"
    description="Testing module for the aws firewall component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_firewall ]

    [#-- base template generation --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "mgmt" : {
                    "Components" : {
                        "firewallbase" : {
                            "Type": "firewall",
                            "deployment:Unit" : "aws-firewall",
                            "Profiles" : {
                                "Testing" : ["firewallbase"]
                            },
                            "Engine" : "network",
                            "Rules" : {
                                "default" : {
                                    "Action" : "drop",
                                    "Priority" : "default",
                                    "Inspection" : "Stateless"
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "firewallbase" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "firewall" : {
                                    "Name" : "networkfirewallXmgmtXfirewallbase",
                                    "Type" : "AWS::NetworkFirewall::Firewall"
                                },
                                "policy" : {
                                    "Name" : "networkfirewallpolicyXmgmtXfirewallbase",
                                    "Type" : "AWS::NetworkFirewall::FirewallPolicy"
                                },
                                "loggingConfig" : {
                                    "Name" : "networkfirewallloggingXmgmtXfirewallbase",
                                    "Type" : "AWS::NetworkFirewall::LoggingConfiguration"
                                }
                            },
                            "Output" : [
                                "networkfirewallXmgmtXfirewallbaseXinterface",
                                "networkfirewallXmgmtXfirewallbaseXarn",
                                "networkfirewallpolicyXmgmtXfirewallbaseXarn"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "firewallbase" : {
                    "firewall" : {
                        "TestCases" : [ "firewallbase" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]

    [#-- Simple Network rule --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "mgmt" : {
                    "Components" : {
                        "firewallsimplenet" : {
                            "Type": "firewall",
                            "deployment:Unit" : "aws-firewall",
                            "Engine" : "network",
                            "Profiles" : {
                                "Testing": [ "firewallsimplenet"]
                            },
                            "Rules" : {
                                "tcpinspect" : {
                                    "Action" : "inspect",
                                    "Inspection" : "Stateless",
                                    "Priority" : 50,
                                    "NetworkTuple" : {
                                        "Destination" : {
                                            "Port" : "anytcp",
                                            "IPAddressGroups" : [ "_global" ]
                                        }
                                    }
                                },
                                "tcpallow" : {
                                    "Action" : "pass",
                                    "Inspection" : "Stateful",
                                    "Priority" : 100,
                                    "NetworkTuple" : {
                                        "Destination" : {
                                            "Port" : "anytcp",
                                            "IPAddressGroups" : [ "_global" ]
                                        }
                                    }
                                },
                                "default" : {
                                    "Action" : "drop",
                                    "Priority" : "default",
                                    "Inspection" : "Stateless"
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "firewallsimplenet" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "firewall" : {
                                    "Name" : "networkfirewallXmgmtXfirewallsimplenet",
                                    "Type" : "AWS::NetworkFirewall::Firewall"
                                },
                                "policy" : {
                                    "Name" : "networkfirewallpolicyXmgmtXfirewallsimplenet",
                                    "Type" : "AWS::NetworkFirewall::FirewallPolicy"
                                },
                                "loggingConfig" : {
                                    "Name" : "networkfirewallloggingXmgmtXfirewallsimplenet",
                                    "Type" : "AWS::NetworkFirewall::LoggingConfiguration"
                                },
                                "tcpStatefulAllow" : {
                                    "Name" : "networkfirewallrulegroupXmgmtXfirewallsimplenetXtcpallow",
                                    "Type" : "AWS::NetworkFirewall::RuleGroup"
                                },
                                "tcpStatelessInspect" : {
                                    "Name" : "networkfirewallrulegroupXmgmtXfirewallsimplenetXtcpinspect",
                                    "Type" : "AWS::NetworkFirewall::RuleGroup"
                                }
                            },
                            "Output" : [
                                "networkfirewallXmgmtXfirewallsimplenetXinterface",
                                "networkfirewallXmgmtXfirewallsimplenetXarn",
                                "networkfirewallpolicyXmgmtXfirewallsimplenetXarn"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "firewallsimplenet" : {
                    "firewall" : {
                        "TestCases" : [ "firewallsimplenet" ]
                    }
                }
            }
        }
    /]

    [#-- Domain Filter --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "mgmt" : {
                    "Components" : {
                        "firewalldomainfilter" : {
                            "Type": "firewall",
                            "deployment:Unit" : "aws-firewall",
                            "Engine" : "network",
                            "Profiles" : {
                                "Testing": [ "firewalldomainfilter" ]
                            },
                            "Rules" : {
                                "tcpinspect" : {
                                    "Action" : "inspect",
                                    "Inspection" : "Stateless",
                                    "Priority" : 50,
                                    "NetworkTuple" : {
                                        "Destination" : {
                                            "Port" : "anytcp",
                                            "IPAddressGroups" : [ "_global" ]
                                        }
                                    }
                                },
                                "hostblock" : {
                                    "Action" : "drop",
                                    "Inspection" : "Stateful",
                                    "Priority" : 100,
                                    "RuleType" : "HostFilter",
                                    "HostFilter" : {
                                        "Hosts" : [
                                            "*.baddomain.com",
                                            "badhost.somewhere.com"
                                        ]
                                    }
                                },
                                "default" : {
                                    "Action" : "drop",
                                    "Priority" : "default",
                                    "Inspection" : "Stateless"
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "firewalldomainfilter" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "firewall" : {
                                    "Name" : "networkfirewallXmgmtXfirewalldomainfilter",
                                    "Type" : "AWS::NetworkFirewall::Firewall"
                                },
                                "policy" : {
                                    "Name" : "networkfirewallpolicyXmgmtXfirewalldomainfilter",
                                    "Type" : "AWS::NetworkFirewall::FirewallPolicy"
                                },
                                "loggingConfig" : {
                                    "Name" : "networkfirewallloggingXmgmtXfirewalldomainfilter",
                                    "Type" : "AWS::NetworkFirewall::LoggingConfiguration"
                                },
                                "hostFilterBlock" : {
                                    "Name" : "networkfirewallrulegroupXmgmtXfirewalldomainfilterXhostblock",
                                    "Type" : "AWS::NetworkFirewall::RuleGroup"
                                },
                                "tcpStatelessInspect" : {
                                    "Name" : "networkfirewallrulegroupXmgmtXfirewalldomainfilterXtcpinspect",
                                    "Type" : "AWS::NetworkFirewall::RuleGroup"
                                }
                            },
                            "Output" : [
                                "networkfirewallXmgmtXfirewalldomainfilterXinterface",
                                "networkfirewallXmgmtXfirewalldomainfilterXarn",
                                "networkfirewallpolicyXmgmtXfirewalldomainfilterXarn"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "firewalldomainfilter" : {
                    "firewall" : {
                        "TestCases" : [ "firewalldomainfilter" ]
                    }
                }
            }
        }
    /]

[/#macro]
