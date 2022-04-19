[#ftl]

[@addModule
    name="datapipeline"
    description="Testing module for the aws hosting of datapipelines"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_datapipeline ]

    [#-- Data Pipeline --]
    [@loadModule
        settingSets=[
            {
                "Type" : "Settings",
                "Scope" : "Accounts",
                "Namespace" : "mockacct-shared",
                "Settings" : {
                    "Registries": {
                        "pipeline": {
                            "EndPoint": "account-registry-abc123",
                            "Prefix": "pipeline/"
                        }
                    }
                }
            },
            {
                "Type" : "Builds",
                "Scope" : "Products",
                "Namespace" : "mockedup-integration-app-datapipelinebase",
                "Settings" : {
                    "COMMIT" : "123456789#MockCommit#",
                    "FORMATS" : ["pipeline"]
                }
            }
        ]
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "datapipelinebase" : {
                            "Type": "datapipeline",
                            "deployment:Unit": "aws-datapipeline",
                            "Profiles" : {
                                "Testing" : [ "datapipelinebase" ]
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "datapipelinebasecli" : {
                    "OutputSuffix" : "cli.json",
                    "Structural" : {
                        "JSON" : {
                            "Match" : {
                                "pipelineName" : {
                                    "Path"  : "datapipelineXappXdatapipelinebase.createPipeline.name",
                                    "Value" : "mockedup-integration-application-datapipelinebase"
                                },
                                "pipelineId" : {
                                    "Path" : "datapipelineXappXdatapipelinebase.createPipeline.uniqueId",
                                    "Value" : "datapipelineXappXdatapipelinebase"
                                }
                            }
                        }
                    }
                },
                "datapipelinebaseconfig" : {
                    "OutputSuffix" : "config.json",
                    "Structural" : {
                        "JSON" : {
                            "Match" : {
                                "vpcId" : {
                                    "Path"  : "values.my_VPC_ID",
                                    "Value" : "vpc-123456789abcdef12"
                                },
                                "PipelineName" : {
                                    "Path" : "values.my_ROLE_PIPELINE_NAME",
                                    "Value" : "mockedup-integration-application-datapipelinebase-pipeline"
                                }
                            }
                        }
                    }
                },
                "datapipelinebasetemplate" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "instanceProfile" : {
                                    "Name" : "instanceProfileXappXdatapipelinebase",
                                    "Type" : "AWS::IAM::InstanceProfile"
                                },
                                "securityGroup" : {
                                    "Name" : "securityGroupXappXdatapipelinebase",
                                    "Type" : "AWS::EC2::SecurityGroup"
                                }
                            },
                            "Output" : [
                                "securityGroupXappXdatapipelinebase"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "datapipelinebase" : {
                    "datapipeline" : {
                        "TestCases" : [ "datapipelinebasecli" ,"datapipelinebaseconfig", "datapipelinebasetemplate" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]
[/#macro]
