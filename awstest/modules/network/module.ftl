[#ftl]

[@addModule
    name="network"
    description="Testing module for the aws hosting of network component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_network  ]

    [#-- base --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "mgmt" : {
                    "Components" : {
                        "networkbase" : {
                            "network" : {
                                "Instances" : {
                                    "default" : {
                                        "DeploymentUnits" : ["aws-network-base"]
                                    }
                                },
                                "Profiles" : {
                                    "Testing" : [ "networkbase" ]
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "networkbase" : {
                    "OutputSuffix" : "template.json",
                    "Tools" : {
                        "CFNLint" : true
                    },
                    "Structural" : {
                    }
                }
            },
            "TestProfiles" : {
                "networkbase" : {
                    "network" : {
                        "TestCases" : [ "networkbase" ]
                    }
                }
            }
        }
    /]

    [#-- Subnet setup --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "network": {
                    "Name": "network",
                    "Title": "Network Tier",
                    "Description": "Overriden tier for subnet testing",
                    "Network": {
                        "Enabled": true,
                        "Link": {
                            "Tier": "mgmt",
                            "Component": "networksubnet",
                            "Instance": "",
                            "Version": ""
                        },
                        "NetworkACL" : "open",
                        "RouteTable" : "internal"
                    },
                    "Components" : {
                        "networksubnetec2" : {
                            "ec2" : {
                                "Instances" : {
                                    "default" : {
                                        "deployment:Unit" : "aws-network-subnet-ec2"
                                    }
                                }
                            }
                        }
                    }
                },
                "mgmt" : {
                    "Components" : {
                        "networksubnet" : {
                            "network" : {
                                "Instances" : {
                                    "default" : {
                                        "deployment:Unit" : "aws-network-subnet"
                                    }
                                },
                                "Profiles" : {
                                    "Testing" : [ "networksubnet" ]
                                },
                                "RouteTables": {
                                    "internal": {},
                                    "external": {
                                        "Public": true
                                    }
                                },
                                "NetworkACLs": {
                                    "open": {
                                        "Rules": {
                                            "in": {
                                                "Priority": 200,
                                                "Action": "allow",
                                                "Source": {
                                                    "IPAddressGroups": [
                                                        "_global"
                                                    ]
                                                },
                                                "Destination": {
                                                    "IPAddressGroups": [
                                                        "_localnet"
                                                    ],
                                                    "Port": "any"
                                                },
                                                "ReturnTraffic": false
                                            },
                                            "out": {
                                                "Priority": 200,
                                                "Action": "allow",
                                                "Source": {
                                                    "IPAddressGroups": [
                                                        "_localnet"
                                                    ]
                                                },
                                                "Destination": {
                                                    "IPAddressGroups": [
                                                        "_global"
                                                    ],
                                                    "Port": "any"
                                                },
                                                "ReturnTraffic": false
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "networksubnet" : {
                    "OutputSuffix" : "template.json",
                    "Tools" : {
                        "CFNLint" : true
                    },
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "vpc" : {
                                    "Name" : "vpcXmgmtXnetworksubnet",
                                    "Type" : "AWS::EC2::VPC"
                                },
                                "subnetA" : {
                                    "Name" : "subnetXmgmtXnetworksubnetXnetworkXa",
                                    "Type" : "AWS::EC2::Subnet"
                                },
                                "subnetB" : {
                                    "Name" : "subnetXmgmtXnetworksubnetXnetworkXb",
                                    "Type" : "AWS::EC2::Subnet"
                                },
                                "networkACL" : {
                                    "Name" : "networkACLXmgmtXnetworksubnetXopen",
                                    "Type" : "AWS::EC2::NetworkAcl"
                                },
                                "routeTableA" : {
                                    "Name" : "routeTableXmgmtXnetworksubnetXinternalXa",
                                    "Type" : "AWS::EC2::RouteTable"
                                },
                                "routeTableB" : {
                                    "Name" : "routeTableXmgmtXnetworksubnetXinternalXb",
                                    "Type" : "AWS::EC2::RouteTable"
                                },
                                "routeTableAsubnetA" : {
                                    "Name" : "associationXsubnetXmgmtXnetworksubnetXnetworkXaXrouteTable",
                                    "Type" : "AWS::EC2::SubnetRouteTableAssociation"
                                },
                                "routeTableBsubnetB" : {
                                    "Name" : "associationXsubnetXmgmtXnetworksubnetXnetworkXbXrouteTable",
                                    "Type" : "AWS::EC2::SubnetRouteTableAssociation"
                                },
                                "networkACLsubnetA" : {
                                    "Name" : "associationXsubnetXmgmtXnetworksubnetXnetworkXaXnetworkACL",
                                    "Type" : "AWS::EC2::SubnetNetworkAclAssociation"
                                },
                                "networkACLsubnetB" : {
                                    "Name" : "associationXsubnetXmgmtXnetworksubnetXnetworkXbXnetworkACL",
                                    "Type" : "AWS::EC2::SubnetNetworkAclAssociation"
                                }
                            },
                            "Output" : [
                                "subnetListXmgmtXnetworksubnetXnetwork",
                                "vpcXmgmtXnetworksubnet"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "vpcCIDR" : {
                                    "Path"  : "Resources.vpcXmgmtXnetworksubnet.Properties.CidrBlock",
                                    "Value" : "10.0.0.0/16"
                                },
                                "subnetACIDR" : {
                                    "Path"  : "Resources.subnetXmgmtXnetworksubnetXnetworkXa.Properties.CidrBlock",
                                    "Value" : "10.0.224.0/22"
                                },
                                "subnetBCIDR" : {
                                    "Path"  : "Resources.subnetXmgmtXnetworksubnetXnetworkXb.Properties.CidrBlock",
                                    "Value" : "10.0.228.0/22"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "networksubnet" : {
                    "network" : {
                        "TestCases" : [ "networksubnet" ]
                    }
                }
            }
        }
    /]

    [#-- logging --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "mgmt" : {
                    "Components" : {
                        "networklogging" : {
                            "network" : {
                                "Instances" : {
                                    "default" : {
                                        "deployment:Unit" : "aws-network-logging"
                                    }
                                },
                                "Profiles" : {
                                    "Testing" : [ "networklogging" ]
                                },
                                "Logging" : {
                                    "FlowLogs" : {
                                        "logall" : {
                                            "Action" : "any",
                                            "DestinationType" : "log"
                                        }
                                    },
                                    "DNSQuery" : {
                                        "log" : {
                                            "DestinationType" : "log"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "networklogging" : {
                    "OutputSuffix" : "template.json",
                    "Tools" : {
                        "CFNLint" : true
                    },
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "dnsQueryLogger" : {
                                    "Name" : "resolverQueryLoggingXmgmtXnetworkloggingXlog",
                                    "Type" : "AWS::Route53Resolver::ResolverQueryLoggingConfig"
                                },
                                "dnsQueryLoggerAssoc" : {
                                    "Name" : "resolverQueryLoggingAsccociationXmgmtXnetworkloggingXlog",
                                    "Type" : "AWS::Route53Resolver::ResolverQueryLoggingConfigAssociation"
                                },
                                "vpcFlowLogs" : {
                                    "Name" : "vpcflowlogsXmgmtXnetworkloggingXlogall",
                                    "Type" : "AWS::EC2::FlowLog"
                                }
                            }
                        },
                        "JSON" : {
                            "Match" : {
                                "FlowLogAll" : {
                                    "Path"  : "Resources.vpcflowlogsXmgmtXnetworkloggingXlogall.Properties.TrafficType",
                                    "Value" : "ALL"
                                },
                                "FlowLogTypeVPC" : {
                                    "Path"  : "Resources.vpcflowlogsXmgmtXnetworkloggingXlogall.Properties.ResourceType",
                                    "Value" : "VPC"
                                },
                                "FlowLogVPC" : {
                                    "Path" : "Resources.vpcflowlogsXmgmtXnetworkloggingXlogall.Properties.ResourceId",
                                    "Value" : "vpc-123456789abcdef12"
                                },
                                "DNSQueryAssocVPC" : {
                                    "Path" : "Resources.resolverQueryLoggingAsccociationXmgmtXnetworkloggingXlog.Properties.ResourceId",
                                    "Value" : "vpc-123456789abcdef12"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "networklogging" : {
                    "network" : {
                        "TestCases" : [ "networklogging" ]
                    }
                }
            }
        }
    /]
[/#macro]
