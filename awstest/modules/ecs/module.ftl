[#ftl]

[@addModule
    name="ecs"
    description="Testing module for the aws ecs component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]


[#macro awstest_module_ecs ]

    [#-- Base setup --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "ecsbase" : {
                            "Type": "ecs",
                            "deployment:Unit" : "aws-ecs",
                            "Profiles" : {
                                "Testing" : [ "ecsbase" ]
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "ecsbase" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "launchConfigId" : {
                                    "Name" : "launchConfigXappXecsbase",
                                    "Type" : "AWS::AutoScaling::LaunchConfiguration"
                                },
                                "secGroup" : {
                                    "Name" : "securityGroupXappXecsbase",
                                    "Type" : "AWS::EC2::SecurityGroup"
                                },
                                "autoScaleGroup" : {
                                    "Name" : "asgXappXecsbase",
                                    "Type" : "AWS::AutoScaling::AutoScalingGroup"
                                },
                                "ecsCluster" : {
                                    "Name" : "ecsXappXecsbase",
                                    "Type" : "AWS::ECS::Cluster"
                                },
                                "asgCapacityProvider" : {
                                    "Name" : "ecsCapacityProviderXappXecsbaseXasg",
                                    "Type" : "AWS::ECS::CapacityProvider"
                                }
                            },
                            "Output" : [
                                "securityGroupXappXecsbase",
                                "asgXappXecsbase",
                                "ecsXappXecsbase",
                                "ecsXappXecsbaseXarn"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "TagName" : {
                                    "Path"  : "Resources.ecsXappXecsbase.Properties.Tags[0].Value",
                                    "Value" : "mockedup-integration-application-ecsbase"
                                },
                                "ASGWaitForCFNSignals" : {
                                    "Path"  : "Resources.asgXappXecsbase.UpdatePolicy.AutoScalingRollingUpdate.WaitOnResourceSignals",
                                    "Value" : true
                                },
                                "SGVPCFound" : {
                                    "Path" : "Resources.securityGroupXappXecsbase.Properties.VpcId",
                                    "Value" : "vpc-123456789abcdef12"
                                },
                                "ECSCapacityProviders" : {
                                    "Path" : "Resources.ecsCapacityProviderAssocXappXecsbase.Properties.CapacityProviders",
                                    "Value" : [
                                        "FARGATE",
                                        "FARGATE_SPOT",
                                        {
                                            "Ref": "ecsCapacityProviderXappXecsbaseXasg"
                                        }
                                    ]
                                }
                            },
                            "NotEmpty" : [
                                "Resources.launchConfigXappXecsbase.Properties.ImageId",
                                "Resources.launchConfigXappXecsbase.Properties.InstanceType",
                                "Resources.asgXappXecsbase.Metadata"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "ecsbase" : {
                    "ecs" : {
                        "TestCases" : [ "ecsbase" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]

[/#macro]
