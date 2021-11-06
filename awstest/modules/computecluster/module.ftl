[#ftl]

[@addModule
    name="computecluster"
    description="Testing module for the aws computecluster component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_computecluster ]

    [#-- Base setup --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "computeclusterbase" : {
                            "computecluster" : {
                                "Instances" : {
                                    "default" : {
                                        "deployment:Unit" : "aws-computecluster-base"
                                    }
                                },
                                "Image" : {
                                    "Source" : "none"
                                },
                                "Profiles" : {
                                    "Testing" : [ "computeclusterbase" ]
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "computeclusterbase" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "secGroup" : {
                                    "Name" : "securityGroupXappXcomputeclusterbase",
                                    "Type" : "AWS::EC2::SecurityGroup"
                                },
                                "autoScaleGroup" : {
                                    "Name" : "asgXappXcomputeclusterbase",
                                    "Type" : "AWS::AutoScaling::AutoScalingGroup"
                                }
                            },
                            "Output" : [
                                "asgXappXcomputeclusterbase",
                                "securityGroupXappXcomputeclusterbase"
                            ]
                        },
                        "JSON" : {
                            "NotEmpty" : [
                                "Resources.launchConfigXappXcomputeclusterbaseXHamletFatalBuildreferencenotfound.Properties.ImageId",
                                "Resources.launchConfigXappXcomputeclusterbaseXHamletFatalBuildreferencenotfound.Properties.InstanceType",
                                "Resources.launchConfigXappXcomputeclusterbaseXHamletFatalBuildreferencenotfound.Properties.UserData",
                                "Resources.asgXappXcomputeclusterbase.Metadata"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "computeclusterbase" : {
                    "computecluster" : {
                        "TestCases" : [ "computeclusterbase" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]

[/#macro]
