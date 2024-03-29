[#ftl]

[@addModule
    name="ec2"
    description="Testing module for the aws ec2 component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_ec2 ]

    [#-- Base setup --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "ec2base" : {
                            "Type": "ec2",
                            "deployment:Unit": "aws-ec2",
                            "Profiles" : {
                                "Testing" : [ "ec2base" ]
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "ec2base" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "secGroup" : {
                                    "Name" : "securityGroupXappXec2base",
                                    "Type" : "AWS::EC2::SecurityGroup"
                                },
                                "ec2InstanceA" : {
                                    "Name" : "ec2InstanceXappXec2baseXa",
                                    "Type" : "AWS::EC2::Instance"
                                },
                                "eniAdaptorA" : {
                                    "Name" : "eniXappXec2baseXaXeth0",
                                    "Type" : "AWS::EC2::NetworkInterface"
                                }
                            },
                            "Output" : [
                                "securityGroupXappXec2base"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "NetworkInterfaceAttached" : {
                                    "Path" : "Resources.ec2InstanceXappXec2baseXa.Properties.NetworkInterfaces[0].NetworkInterfaceId",
                                    "Value" : {
                                        "Ref": "eniXappXec2baseXaXeth0"
                                    }
                                },
                                "NetworkInterfaceSubnet" : {
                                    "Path" : "Resources.eniXappXec2baseXaXeth0.Properties.SubnetId",
                                    "Value" : "subnet-123456789abcdef13"
                                }
                            },
                            "NotEmpty" : [
                                "Resources.ec2InstanceXappXec2baseXa.Properties.ImageId",
                                "Resources.ec2InstanceXappXec2baseXa.Properties.InstanceType",
                                "Resources.ec2InstanceXappXec2baseXa.Metadata"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "ec2base" : {
                    "ec2" : {
                        "TestCases" : [ "ec2base" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]

[/#macro]
