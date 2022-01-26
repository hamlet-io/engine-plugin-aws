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
                            "deployment:Unit" : "aws-backupstore-base",
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
                                    "Name" : "backupvaultXdbXbackup",
                                    "Type" : "AWS::Backup::BackupVault"
                                }
                            },
                            "Output" : [
                                "backupvaultXdbXbackupXname"
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
    /]
[/#macro]
