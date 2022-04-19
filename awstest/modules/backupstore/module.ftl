[#ftl]

[@addModule
    name="backupstore"
    description="Testing module for the aws backupstore component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]


[#macro awstest_module_backupstore ]

    [#-- Base backup store setup --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "db" : {
                    "Components" : {
                        "backupstorebase" : {
                            "Type" : "backupstore",
                            "deployment:Unit" : "aws-backupstore",
                            "Profiles" : {
                                "Testing" : [ "backupstorebase" ]
                            },
                            "Encryption" : {
                                "Enabled" : true
                            },
                            "Regimes" : {
                                "daily" : {
                                    "Rules" : {
                                        "default" : {
                                            "Schedule" : "cron(45 06 ? * * *)",
                                            "Lifecycle" : {
                                                "Expiration" : 70
                                            }
                                        }
                                    },
                                    "Targets" : {
                                        "Tag" : {
                                                "Enabled" : true
                                        }
                                    }
                                },
                                "monthly" : {
                                    "Rules" : {
                                        "default" : {
                                            "Schedule" : "cron(0 09 1 * * *)",
                                            "Lifecycle" : {
                                                "Expiration" : 800
                                            }
                                        }
                                    },
                                    "Targets" : {
                                        "Tag" : {
                                            "Enabled" : true
                                        }
                                    }
                                },
                                "yearly" : {
                                    "Rules" : {
                                        "default" : {
                                            "Schedule" : "cron(0 10 1 1 * *)",
                                            "Lifecycle" : {
                                                "Expiration" : 2600
                                            }
                                        }
                                    },
                                    "Targets" : {
                                        "Tag" : {
                                            "Enabled" : true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "backupstorebase" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "vault" : {
                                    "Name" : "backupvaultXdbXbackupstorebase",
                                    "Type" : "AWS::Backup::BackupVault"
                                }
                            },
                            "Output" : [
                                "backupvaultXdbXbackupstorebaseXname"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "backupstorebase" : {
                    "backupstore" : {
                        "TestCases" : [ "backupstorebase" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
        stackOutputs=[
            {
                "Account" : "0123456789",
                "Region" : "mock-region-1",
                "DeploymentUnit" : "aws-backupstore",
                "backupvaultXdbXbackupstorebase": "mockedup-integration-database-backupstorebase"
            },
            {
                "Account" : "0123456789",
                "Region" : "mock-region-1",
                "DeploymentUnit" : "aws-backupstore",
                "backupplanXdbXbackupstorebaseXdaily": "mockedup-integration-database-backupstorebase-daily"
            },
            {
                "Account" : "0123456789",
                "Region" : "mock-region-1",
                "DeploymentUnit" : "aws-backupstore",
                "backupplanXdbXbackupstorebaseXmonthly": "mockedup-integration-database-backupstorebase-monthly"
            },
            {
                "Account" : "0123456789",
                "Region" : "mock-region-1",
                "DeploymentUnit" : "aws-backupstore",
                "backupplanXdbXbackupstorebaseXyearly": "mockedup-integration-database-backupstorebase-yearly"
            }
        ]
    /]


    [#-- Tag Condition selection --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "mgmt" : {
                    "Components" : {
                        "backupstoretags" : {
                            "Type" : "backupstore",
                            "deployment:Unit" : "aws-backupstore",
                            "Profiles" : {
                                "Testing" : [ "backupstoretags" ]
                            },
                            "Regimes": {
                                "dailysegment": {
                                    "Targets": {
                                        "All": {
                                            "Enabled": true
                                        }
                                    },
                                    "Rules": {
                                        "daily": {
                                            "PointInTimeSupport": true,
                                            "Expression": "rate(1 day)"
                                        }
                                    },
                                    "Conditions": {
                                        "MatchesStore": {
                                            "Tier": false,
                                            "Enabled": true,
                                            "Product": true,
                                            "Environment": true,
                                            "Segment": true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "backupstoretags" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "vault" : {
                                    "Name" : "backupvaultXmgmtXbackupstoretags",
                                    "Type" : "AWS::Backup::BackupVault"
                                }
                            },
                            "Output" : [
                                "backupvaultXmgmtXbackupstoretagsXname"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "ConditionTagNaming" : {
                                    "Path"  : "Resources.backupselectionXmgmtXbackupstoretagsXdailysegment.Properties.BackupSelection.Conditions.StringEquals[0].ConditionKey",
                                    "Value" : "aws:ResourceTag/cot:product"
                                }
                            },
                            "Length" : {
                                "TagConditions" : {
                                    "Path": "Resources.backupselectionXmgmtXbackupstoretagsXdailysegment.Properties.BackupSelection.Conditions.StringEquals",
                                    "Count": 3
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "backupstoretags" : {
                    "backupstore" : {
                        "TestCases" : [ "backupstoretags" ]
                    }
                }
            }
        }
        stackOutputs=[
            {
                "Account" : "0123456789",
                "Region" : "mock-region-1",
                "DeploymentUnit" : "aws-backupstore",
                "backupvaultXmgmtXbackupstoretags": "mockedup-integration-management-backupstoretags"
            },
            {
                "Account" : "0123456789",
                "Region" : "mock-region-1",
                "DeploymentUnit" : "aws-backupstore",
                "backupplanXmgmtXbackupstoretagsXdailysegment": "mockedup-integration-management-backupstoretags-dailysegment"
            }
        ]
    /]
[/#macro]
