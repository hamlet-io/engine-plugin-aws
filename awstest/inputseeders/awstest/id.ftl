[#ftl]
[@registerInputSeeder
    id=AWSTEST_INPUT_SEEDER
    description="AWS test provider inputs"
/]

[@addSeederToConfigPipeline
    stage=FIXTURE_SHARED_INPUT_STAGE
    seeder=AWSTEST_INPUT_SEEDER
/]

[#function awstest_configseeder_fixture filter state]

    [#if filterAttributeContainsValue(filter, "Provider", AWS_PROVIDER) ]
        [#return
            addToConfigPipelineClass(
                state,
                BLUEPRINT_CONFIG_INPUT_CLASS,
                {
                    "Solution" : {
                        "Modules" : {
                            "apigateway" : {
                                "Provider" : "awstest",
                                "Name" : "apigateway"
                            },
                            "bastion" : {
                                "Provider" : "awstest",
                                "Name" : "bastion"
                            },
                            "computecluster" : {
                                "Provider" : "awstest",
                                "Name" : "computecluster"
                            },
                            "contentnode" : {
                                "Provider" : "awstest",
                                "Name" : "contentnode"
                            },
                            "datapipeline" : {
                                "Provider" : "awstest",
                                "Name" : "datapipeline"
                            },
                            "dataset" : {
                                "Provider" : "awstest",
                                "Name" : "dataset"
                            },
                            "ec2" : {
                                "Provider" : "awstest",
                                "Name" : "ec2"
                            },
                            "ecs" : {
                                "Provider" : "awstest",
                                "Name" : "ecs"
                            },
                            "db" : {
                                "Provider" : "awstest",
                                "Name" : "db"
                            },
                            "ecs" : {
                                "Provider" : "awstest",
                                "Name" : "ecs"
                            },
                            "filetransfer" : {
                                "Provider" : "awstest",
                                "Name" : "filetransfer"
                            },
                            "healthcheck" : {
                                "Provider" : "awstest",
                                "Name" : "healthcheck"
                            },
                            "lb" : {
                                "Provider" : "awstest",
                                "Name" : "lb"
                            },
                            "mobileapp" : {
                                "Provider" : "awstest",
                                "Name" : "mobileapp"
                            },
                            "s3" : {
                                "Provider" : "awstest",
                                "Name" : "s3"
                            },
                            "service" : {
                                "Provider" : "awstest",
                                "Name" : "service"
                            },
                            "task" : {
                                "Provider" : "awstest",
                                "Name" : "task"
                            },
                            "userpool" : {
                                "Provider" : "awstest",
                                "Name" : "userpool"
                            },
                            "queuehost" : {
                                "Provider" : "awstest",
                                "Name" : "queuehost"
                            }
                        }
                    },
                    "DeploymentGroups" : {
                        "segment" : {
                            "ResourceSets" : {
                                "iam" : {
                                    "Enabled" : false
                                },
                                "lg" : {
                                    "Enabled" : false
                                },
                                "eip" : {
                                    "Enabled" : false
                                },
                                "s3" : {
                                    "Enabled" : false
                                },
                                "cmk" : {
                                    "Enabled" : false
                                }
                            }
                        },
                        "solution" : {
                            "ResourceSets" : {
                                "eip" : {
                                    "Enabled" : false
                                },
                                "iam" : {
                                    "Enabled" : false
                                },
                                "lg" : {
                                    "Enabled" : false
                                }
                            }
                        },
                        "application" : {
                            "ResourceSets" : {
                                "iam" : {
                                    "Enabled" : false
                                },
                                "lg" : {
                                    "Enabled" : false
                                }
                            }
                        }
                    }
                },
                FIXTURE_SHARED_INPUT_STAGE
            )
        ]
    [/#if]

    [#return state]

[/#function]

[#function awstest_configseeder_fixture_mock filter state]

    [#if filterAttributeContainsValue(filter, "Provider", AWS_PROVIDER) ]
        [#return
            addToConfigPipelineClass(
                awstest_configseeder_fixture(filter, state),
                BLUEPRINT_CONFIG_INPUT_CLASS,
                {
                    "DeploymentGroups" : {
                        "segment" : {
                            "ResourceSets" : {
                                "iam" : {
                                    "Enabled" : false
                                },
                                "lg" : {
                                    "Enabled" : false
                                },
                                "eip" : {
                                    "Enabled" : false
                                },
                                "s3" : {
                                    "Enabled" : false
                                },
                                "cmk" : {
                                    "Enabled" : false
                                }
                            }
                        },
                        "solution" : {
                            "ResourceSets" : {
                                "eip" : {
                                    "Enabled" : false
                                },
                                "iam" : {
                                    "Enabled" : false
                                },
                                "lg" : {
                                    "Enabled" : false
                                }
                            }
                        },
                        "application" : {
                            "ResourceSets" : {
                                "iam" : {
                                    "Enabled" : false
                                },
                                "lg" : {
                                    "Enabled" : false
                                }
                            }
                        }
                    }
                },
                FIXTURE_SHARED_INPUT_STAGE
            )
        ]
    [/#if]

    [#return state]

[/#function]
