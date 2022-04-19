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
                            "Type": "s3",
                            "deployment:Unit" : "aws-s3",
                            "Profiles" : {
                                "Testing" : [ "s3base" ]
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
                }
            }
        }
    /]

    [@loadModule
        blueprint={
            "Tiers": {
                "app": {
                    "Components": {
                        "s3notify" : {
                            "Type": "s3",
                            "deployment:Unit" : "aws-s3",
                            "Profiles" : {
                                "Testing" : [ "s3notify" ]
                            },
                            "Notifications" : {
                                "sqsCreate" : {
                                    "Links" : {
                                        "s3notifyqueue" : {
                                            "Tier" : "app",
                                            "Component" : "s3notify_queue"
                                        }
                                    },
                                    "aws:QueuePermissionMigration" : true
                                }
                            }
                        },
                        "s3notify_queue" : {
                            "Type": "sqs",
                            "deployment:Unit" : "aws-s3",
                            "Links" : {
                                "s3Notify" :{
                                    "Tier" : "app",
                                    "Component" : "s3notify",
                                    "Direction" : "inbound",
                                    "Role" : "invoke"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" :{
                "s3notify" : {
                    "s3" : {
                        "TestCases" : [ "s3notify" ]
                    }
                }
            },
            "TestCases": {
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
                                    "Name" : "sqsXappXs3notifyXqueue",
                                    "Type" : "AWS::SQS::Queue"
                                },
                                "sqsQueuePolicy" : {
                                    "Name" : "sqsPolicyXappXs3notifyXqueue",
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
                                    "Value" :  {
                                        "Fn::GetAtt": [
                                            "sqsXappXs3notifyXqueue",
                                            "Arn"
                                        ]
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        stackOutputs=[
            {
                "Account" : "0123456789",
                "Region" : "mock-region-1",
                "DeploymentUnit" : "aws-s3",

                "s3XappXs3notify" : "mockedup-integration-application-s3notify-568132487",
                "s3XappXs3notifyXname": "mockedup-integration-application-s3notify-568132487",
                "s3XappXs3notifyXarn": "arn:s3:::mockedup-integration-application-s3notify-568132487",

                "sqsXappXs3notifyXqueue": "mockedup-integration-application-s3notify_queue",
                "sqsXappXs3notifyXqueueXarn": "arn:aws:sqs:mock-region-1:0123456789:mockedup-integration-application-s3notify_queue"
            }
        ]
    /]

    [@loadModule
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "s3replica_src" : {
                            "Type": "s3",
                            "deployment:Unit" : "aws-s3",
                            "Profiles" : {
                                "Testing" : [ "s3replica" ]
                            },
                            "Replication" : {
                                "Enabled" : true
                            },
                            "Links" : {
                                "s3replicadst" : {
                                    "Tier" : "app",
                                    "Component" : "s3replica_dst",
                                    "Role" : "replicadestination"
                                }
                            }
                        },
                        "s3replica_dst" : {
                            "Type": "s3",
                            "deployment:Unit" : "aws-s3"
                        }
                    }
                }
            },
            "TestProfiles" : {
                "s3replica" : {
                    "s3" : {
                        "TestCases" : [ "s3replica" ]
                    }
                }
            },
            "TestCases" : {
                "s3replica" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "s3BucketSource" : {
                                    "Name" : "s3XappXs3replicaXsrc",
                                    "Type" : "AWS::S3::Bucket"
                                },
                                "s3BucketDestination" : {
                                    "Name" : "s3XappXs3replicaXdst",
                                    "Type" : "AWS::S3::Bucket"
                                }
                            },
                            "Output" : [
                                "s3XappXs3replicaXsrc",
                                "s3XappXs3replicaXsrcXname",
                                "s3XappXs3replicaXsrcXarn",
                                "s3XappXs3replicaXsrcXregion",
                                "s3XappXs3replicaXdst",
                                "s3XappXs3replicaXdstXname",
                                "s3XappXs3replicaXdstXarn",
                                "s3XappXs3replicaXdstXregion"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "S3NotificationsCreateEvent" : {
                                    "Path"  : "Resources.s3XappXs3replicaXsrc.Properties.ReplicationConfiguration.Rules[0].Destination.Bucket",
                                    "Value" : "arn:s3:::mockedup-integration-application-s3replica-dst-568132487"
                                }
                            }
                        }
                    }
                }
            }
        }
        stackOutputs=[
            {
                "Account" : "0123456789",
                "Region" : "mock-region-1",
                "DeploymentUnit" : "aws-s3",

                "s3XappXs3replicaXdst" : "mockedup-integration-application-s3replica-dst-568132487",
                "s3XappXs3replicaXdstXname": "mockedup-integration-application-s3replica-dst-568132487",
                "s3XappXs3replicaXdstXarn": "arn:s3:::mockedup-integration-application-s3replica-dst-568132487"
            }
        ]
    /]

    [@loadModule
        blueprint={
            "Tiers": {
                "app": {
                    "Components": {
                        "s3replicasexternal_src" : {
                            "Type": "s3",
                            "deployment:Unit" : "aws-s3",
                            "Profiles" : {
                                "Testing" : [ "s3replicaext" ]
                            },
                            "Replication" : {
                                "Enabled" : true
                            },
                            "Links" : {
                                "s3replicaext" : {
                                    "Tier" : "app",
                                    "Component" : "s3replicasexternal_dst",
                                    "Role" : "replicadestination"
                                }
                            }
                        },
                        "s3replicasexternal_dst" : {
                            "Type": "externalservice",
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
            },
            "TestProfiles": {
                "s3replicaext" : {
                    "s3" : {
                        "TestCases" : [ "s3replicaext" ]
                    }
                }
            },
            "TestCases": {
                "s3replicaext" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "s3BucketSource" : {
                                    "Name" : "s3XappXs3replicasexternalXsrc",
                                    "Type" : "AWS::S3::Bucket"
                                }
                            },
                            "Output" : [
                                "s3XappXs3replicasexternalXsrc",
                                "s3XappXs3replicasexternalXsrcXname",
                                "s3XappXs3replicasexternalXsrcXarn",
                                "s3XappXs3replicasexternalXsrcXregion"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "ReplicationRuleDestination" : {
                                    "Path"  : "Resources.s3XappXs3replicasexternalXsrc.Properties.ReplicationConfiguration.Rules[0].Destination.Bucket",
                                    "Value" : "arn:aws:s3:::external-replication-destination"
                                },
                                "ReplicationRuleDestinationTranslation" : {
                                    "Path"  : "Resources.s3XappXs3replicasexternalXsrc.Properties.ReplicationConfiguration.Rules[0].Destination.AccessControlTranslation.Owner",
                                    "Value" : "Destination"
                                },
                                "ReplicationRuleDestinationOwner" : {
                                    "Path"  : "Resources.s3XappXs3replicasexternalXsrc.Properties.ReplicationConfiguration.Rules[0].Destination.Account",
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
