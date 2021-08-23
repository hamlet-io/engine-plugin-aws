[#ftl]

[@addModule
    name="bastion"
    description="Testing module for the aws bastion component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]


[#macro awstest_module_bastion ]

    [#-- Base setup --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "mgmt" : {
                    "Components" : {
                        "bastionbase" : {
                            "bastion" : {
                                "Instances" : {
                                    "default" : {
                                        "deployment:Unit" : "aws-bastion-base"
                                    }
                                },
                                "Profiles" : {
                                    "Testing" : [ "bastionbase" ]
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "bastionbase" : {
                    "OutputSuffix" : "template.json",
                    "Tools" : {
                       "CFNLint" : true
                    },
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "launchConfigId" : {
                                    "Name" : "launchConfigXmgmtXbastionbase",
                                    "Type" : "AWS::AutoScaling::LaunchConfiguration"
                                },
                                "secGroup" : {
                                    "Name" : "securityGroupXmgmtXbastionbase",
                                    "Type" : "AWS::EC2::SecurityGroup"
                                },
                                "autoScaleGroup" : {
                                    "Name" : "asgXmgmtXbastionbase",
                                    "Type" : "AWS::AutoScaling::AutoScalingGroup"
                                }
                            },
                            "Output" : [
                                "securityGroupXmgmtXbastionbase",
                                "asgXmgmtXbastionbase"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "ASGWaitForCFNSignals" : {
                                    "Path"  : "Resources.asgXmgmtXbastionbase.UpdatePolicy.AutoScalingRollingUpdate.WaitOnResourceSignals",
                                    "Value" : true
                                },
                                "ASGNoInstancesStarted" : {
                                    "Path"  : "Resources.asgXmgmtXbastionbase.Properties.DesiredCapacity",
                                    "Value" : "0"
                                },
                                "SGVPCFound" : {
                                    "Path" : "Resources.securityGroupXmgmtXbastionbase.Properties.VpcId",
                                    "Value" : "vpc-123456789abcdef12"
                                }
                            },
                            "NotEmpty" : [
                                "Resources.launchConfigXmgmtXbastionbase.Properties.ImageId",
                                "Resources.launchConfigXmgmtXbastionbase.Properties.InstanceType",
                                "Resources.asgXmgmtXbastionbase.Metadata"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "bastionbase" : {
                    "bastion" : {
                        "TestCases" : [ "bastionbase" ]
                    }
                }
            }
        }
    /]

[/#macro]
