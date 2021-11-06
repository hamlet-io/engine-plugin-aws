[#ftl]

[@addModule
    name="s3"
    description="Testing module for the aws s3 component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_s3  ]

    [#-- Base S3 - No default parameters --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "s3base" : {
                            "s3" : {
                                "Instances" : {
                                    "default" : {
                                        "deployment:Unit" : "aws-s3-base"
                                    }
                                },
                                "Profiles" : {
                                    "Testing" : [ "s3base" ]
                                }
                            }
                        },
                        "s3notify" : {
                            "s3" : {
                                "Instances" : {
                                    "default" : {
                                        "deployment:Unit" : "aws-s3-notify"
                                    }
                                },
                                "Profiles" : {
                                    "Testing" : [ "s3notify" ]
                                },
                                "Notifications" : {
                                    "sqsCreate" : {
                                        "Links" : {
                                            "s3notifyqueue" : {
                                                "Tier" : "app",
                                                "Component" : "s3notifyqueue",
                                                "Instance" : "",
                                                "Version" : ""
                                            }
                                        },
                                        "aws:QueuePermissionMigration" : true
                                    }
                                }
                            }
                        },
                        "s3notifyqueue" : {
                            "sqs" : {
                                "Instances" : {
                                    "default" : {
                                        "deployment:Unit" : "aws-s3-notify"
                                    }
                                },
                                "Links" : {
                                    "s3Notify" :{
                                        "Tier" : "app",
                                        "Component" : "s3notify",
                                        "Instance" : "",
                                        "Version" : "",
                                        "Direction" : "inbound",
                                        "Role" : "invoke"
                                    }
                                }
                            }
                        },
                        "s3replicasrc" : {
                            "s3" : {
                                "Instances" : {
                                    "default" : {
                                        "deployment:Unit" : "aws-s3-replication"
                                    }
                                },
                                "Profiles" : {
                                    "Testing" : [ "s3replica" ]
                                },
                                "Replication" : {
                                    "Enabled" : true
                                },
                                "Links" : {
                                    "s3replicadst" : {
                                        "Tier" : "app",
                                        "Component" : "s3replicadst",
                                        "Role" : "replicadestination"
                                    }
                                }
                            }
                        },
                        "s3replicadst" : {
                            "s3" : {
                                "Instances" : {
                                    "default" : {
                                        "deployment:Unit" : "aws-s3-replication"
                                    }
                                }
                            }
                        },
                        "s3replicasextrc" : {
                            "s3" : {
                                "Instances" : {
                                    "default" : {
                                        "deployment:Unit" : "aws-s3-replication-external"
                                    }
                                },
                                "Profiles" : {
                                    "Testing" : [ "s3replicaext" ]
                                },
                                "Replication" : {
                                    "Enabled" : true
                                },
                                "Links" : {
                                    "s3replicaext" : {
                                        "Tier" : "app",
                                        "Component" : "s3replicaext",
                                        "Role" : "replicadestination"
                                    }
                                }
                            }
                        },
                        "s3replicaext" : {
                            "externalservice" : {
                                "Instances" : {
                                    "default" : {}
                                },
                                "Profiles" : {
                                    "Placement" : "external"
                                },
                                "Properties" : {
                                    "bucketArn" : {
                                        "Key" : "ARN",
                                        "Value" : "arn:aws:s3:::external-replication-destination"
                                    },
                                    "bucketAccount" : {
                                        "Key" : "ACCOUNT_ID",
                                        "Value" : "0987654321"
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "s3base" : {
                    "s3" : {
                        "TestCases" : [ "s3base" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                },
                "s3notify" : {
                    "s3" : {
                        "TestCases" : [ "s3notify" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                },
                "s3replica" : {
                    "s3" : {
                        "TestCases" : [ "s3replica" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                },
                "s3replicaext" : {
                    "s3" : {
                        "TestCases" : [ "s3replicaext" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            },
            "TestCases" : {
                "s3base" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "s3Bucket" : {
                                    "Name" : "s3XappXs3base",
                                    "Type" : "AWS::S3::Bucket"
                                }
                            },
                            "Output" : [
                                "s3XappXs3base",
                                "s3XappXs3baseXname",
                                "s3XappXs3baseXarn",
                                "s3XappXs3baseXregion"
                            ]
                        }
                    }
                },
                "s3notify" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "s3Bucket" : {
                                    "Name" : "s3XappXs3notify",
                                    "Type" : "AWS::S3::Bucket"
                                },
                                "sqsQueue" : {
                                    "Name" : "sqsXappXs3notifyqueue",
                                    "Type" : "AWS::SQS::Queue"
                                },
                                "sqsQueuePolicy" : {
                                    "Name" : "sqsPolicyXappXs3notifyqueue",
                                    "Type" : "AWS::SQS::QueuePolicy"
                                }
                            },
                            "Output" : [
                                "s3XappXs3notify",
                                "s3XappXs3notifyXname",
                                "s3XappXs3notifyXarn",
                                "s3XappXs3notifyXregion"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "S3NotificationsCreateEvent" : {
                                    "Path"  : "Resources.s3XappXs3notify.Properties.NotificationConfiguration.QueueConfigurations[0].Event",
                                    "Value" : "s3:ObjectCreated:*"
                                },
                                "S3NotificationsCreateEvent" : {
                                    "Path"  : "Resources.s3XappXs3notify.Properties.NotificationConfiguration.QueueConfigurations[0].Queue",
                                    "Value" : "arn:aws:iam::123456789012:mock/sqsXappXs3notifyqueueXarn"
                                }
                            }
                        }
                    }
                },
                "s3replica" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "s3BucketSource" : {
                                    "Name" : "s3XappXs3replicasrc",
                                    "Type" : "AWS::S3::Bucket"
                                },
                                "s3BucketDestination" : {
                                    "Name" : "s3XappXs3replicadst",
                                    "Type" : "AWS::S3::Bucket"
                                }
                            },
                            "Output" : [
                                "s3XappXs3replicasrc",
                                "s3XappXs3replicasrcXname",
                                "s3XappXs3replicasrcXarn",
                                "s3XappXs3replicasrcXregion",
                                "s3XappXs3replicadst",
                                "s3XappXs3replicadstXname",
                                "s3XappXs3replicadstXarn",
                                "s3XappXs3replicadstXregion"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "S3NotificationsCreateEvent" : {
                                    "Path"  : "Resources.s3XappXs3replicasrc.Properties.ReplicationConfiguration.Rules[0].Destination.Bucket",
                                    "Value" : "arn:aws:iam::123456789012:mock/s3XappXs3replicadstXarn"
                                }
                            }
                        }
                    }
                },
                "s3replicaext" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "s3BucketSource" : {
                                    "Name" : "s3XappXs3replicasextrc",
                                    "Type" : "AWS::S3::Bucket"
                                }
                            },
                            "Output" : [
                                "s3XappXs3replicasextrc",
                                "s3XappXs3replicasextrcXname",
                                "s3XappXs3replicasextrcXarn",
                                "s3XappXs3replicasextrcXregion"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "ReplicationRuleDestination" : {
                                    "Path"  : "Resources.s3XappXs3replicasextrc.Properties.ReplicationConfiguration.Rules[0].Destination.Bucket",
                                    "Value" : "arn:aws:s3:::external-replication-destination"
                                },
                                "ReplicationRuleDestinationTranslation" : {
                                    "Path"  : "Resources.s3XappXs3replicasextrc.Properties.ReplicationConfiguration.Rules[0].Destination.AccessControlTranslation.Owner",
                                    "Value" : "Destination"
                                },
                                "ReplicationRuleDestinationOwner" : {
                                    "Path"  : "Resources.s3XappXs3replicasextrc.Properties.ReplicationConfiguration.Rules[0].Destination.Account",
                                    "Value" : "0987654321"
                                }
                            }
                        }
                    }
                }
            }
        }
    /]
[/#macro]
