[#ftl]

[@addModule
    name="runbook_rds_snapshot"
    description="Create a native snapshot of an RDS cluster or instance"
    provider=AWS_PROVIDER
    properties=[
        {
            "Names" : "dbLink",
            "Description" : "A link to the db component running postgres that the dump will be created from",
            "Mandatory" : true,
            "AttributeSet" : LINK_ATTRIBUTESET_TYPE
        }
    ]
/]

[#macro aws_module_runbook_rds_snapshot dbLink ]

    [@loadModule
        blueprint={
            "Tiers" : {
                dbLink.Tier : {
                    "Components" : {
                        "${dbLink.Component}_snpashot" : {
                            "Description" : "Creates an rds native snapshot of the database",
                            "Type" : "runbook",
                            "Engine" : "hamlet",
                            "Inputs" : {
                                "SnapshotName" : {
                                    "Type" : STRING_TYPE,
                                    "Description" : "The name of the snapshot",
                                    "Mandatory" : true
                                },
                                "IncludeDateSuffix" : {
                                    "Type" : BOOLEAN_TYPE,
                                    "Description" : "Include a date based suffix to the snapshot name -YYYMMDD-HHMM",
                                    "Default" : true
                                }
                            },
                            "Steps" : {
                                "aws_login" : {
                                    "Priority" : 5,
                                    "Extensions" : [ "_runbook_get_provider_id" ],
                                    "Task" : {
                                        "Type" : "set_provider_credentials",
                                        "Parameters" : {
                                            "Account" : {
                                                "Value" : "__setting:ACCOUNT__"
                                            }
                                        }
                                    }
                                },
                                "cluster_snapshot" : {
                                    "Priority" : 10,
                                    "Extensions" : [ "_runbook_get_region" ],
                                    "Conditions" :{
                                        "isCluster" : {
                                            "Value" : "__attribute:db:TYPE__",
                                            "Test" : "cluster",
                                            "Match" : "Equals"
                                        }
                                    },
                                    "Task" : {
                                        "Type" : "aws_rds_create_snapshot",
                                        "Parameters" : {
                                            "DbId" : {
                                                "Value" : "__attribute:db:INSTANCEID__"
                                            },
                                            "SnapshotName" : {
                                                "Value" : "__input:SnapshotName__"
                                            },
                                            "Cluster" : {
                                                "Value" : true
                                            },
                                            "IncludeDateSuffix" : {
                                                "Value" : "__input:IncludeDateSuffix__"
                                            },
                                            "AWSAccessKeyId" : {
                                                "Value" : "__output:aws_login:aws_access_key_id__"
                                            },
                                            "AWSSecretAccessKey" : {
                                                "Value" : "__output:aws_login:aws_secret_access_key__"
                                            },
                                            "AWSSessionToken" : {
                                                "Value" : "__output:aws_login:aws_session_token__"
                                            }
                                        }
                                    },
                                    "Links" : {
                                        "db" : dbLink
                                    }
                                },
                                "instance_snapshot" : {
                                    "Priority" : 10,
                                    "Extensions" : [ "_runbook_get_region" ],
                                    "Conditions" :{
                                        "isCluster" : {
                                            "Value" : "__attribute:db:TYPE__",
                                            "Test" : "instance",
                                            "Match" : "Equals"
                                        }
                                    },
                                    "Task" : {
                                        "Type" : "aws_rds_create_snapshot",
                                        "Parameters" : {
                                            "DbId" : {
                                                "Value" : "__attribute:db:INSTANCEID__"
                                            },
                                            "SnapshotName" : {
                                                "Value" : "__input:SnapshotName__"
                                            },
                                            "Cluster" : {
                                                "Value" : false
                                            },
                                            "IncludeDateSuffix" : {
                                                "Value" : "__input:IncludeDateSuffix__"
                                            },
                                            "AWSAccessKeyId" : {
                                                "Value" : "__output:aws_login:aws_access_key_id__"
                                            },
                                            "AWSSecretAccessKey" : {
                                                "Value" : "__output:aws_login:aws_secret_access_key__"
                                            },
                                            "AWSSessionToken" : {
                                                "Value" : "__output:aws_login:aws_session_token__"
                                            }
                                        }
                                    },
                                    "Links" : {
                                        "db" : dbLink
                                    }
                                },
                                "echo_snapshot_arn" : {
                                    "Priority" : 120,
                                    "Task" : {
                                        "Type" : "output_echo",
                                        "Parameters" : {
                                            "Value" : {
                                                "Value" : "__output:cluster_snapshot:SnapshotArn____output:instance_snapshot:SnapshotArn__"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    /]
[/#macro]
