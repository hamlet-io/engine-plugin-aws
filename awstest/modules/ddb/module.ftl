[#ftl]

[@addModule
    name="ddb"
    description="Testing module for the aws ddb component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]


[#macro awstest_module_db ]

    [#-- Base database setup --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "db" : {
                    "Components" : {
                        "docdbbase" : {
                            "Type" : "ddb",
                            "deployment:Unit" : "aws-docdb-base",
                            "EngineVersion" : "4.0",
                            "Port": "mongodb",
                            "Profiles" : {
                                "Testing" : [ "docdbbase" ]
                            },
                            "GenerateCredentials": {
                                "Enabled": true,
                                "EncryptionScheme": "base64"
                            }
                        }
                    }
                }
            },
            "Processors" : {
                "docdbbase" : {
                    "ddb" : {
                        "Processor" : "db.t3.medium",
                        "MinCount" : 2,
                        "MaxCount" : 2,
                        "DesiredCount" : 2
                    }
                }
            },
            "TestCases" : {
                "docdbbase" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "ddsCluster" : {
                                    "Name" : "ddsClusterXdbXdocdb",
                                    "Type" : "AWS::DocDB::DBCluster"
                                },
                                "ddsInstanceA1" : {
                                    "Name" : "ddsXdbXdocdbXaX1",
                                    "Type" : "AWS::DocDB::DBInstance"
                                },
                                "ddsInstanceA2" : {
                                    "Name" : "ddsXdbXdocdbXaX2",
                                    "Type" : "AWS::DocDB::DBInstance"
                                },
                                "rdsParameterGroup" : {
                                    "Name" : "ddsClusterParameterGroupXdbXdocdbXdocdb4X0",
                                    "Type" : "AWS::DocDB::DBClusterParameterGroup"
                                }
                            },
                            "Output" : [
                                "ddsClusterXdbXdocdbXdns",
                                "ddsXdbXdocdbXaX1Xport",
                                "securityGroupXddsClusterXdbXdocdb"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "DocDBEngineVersion" : {
                                    "Path"  : "Resources.ddsClusterXdbXdocdb.Properties.EngineVersion",
                                    "Value" : "4.0"
                                },
                                "ParameterGroupVersion" : {
                                    "Path" : "Resources.ddsClusterParameterGroupXdbXdocdbXdocdb4X0.Properties.Family",
                                    "Value" : "docdb4.0"
                                }
                            },
                            "NotEmpty" : [
                                "Resources.rdsXdbXdocdbbase.Properties.DBInstanceClass"
                            ]
                        }
                    },
                    "Tools": {
                        "cfn-lint": {
                            "IgnoreChecks": [ "E3035", "E3036" ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "docdbbase" : {
                    "ddb" : {
                        "TestCases" : [ "docdbbase" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]

    [#-- Generated creds --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "db" : {
                    "Components" : {
                        "docdbsecretstore" : {
                            "Type" : "ddb",
                            "deployment:Unit" : "aws-docdb-secretstore",
                            "EngineVersion" : "4.0",
                            "Port": "mongodb",
                            "Profiles" : {
                                "Testing" : [ "docdbsecretstore" ]
                            },
                            "rootCredential:Source" : "SecretStore",
                            "rootCredential:SecretStore" : {
                                "Link" : {
                                    "Tier" : "db",
                                    "Component": "docdbsecretstore-secretstore"
                                }
                            }
                        },
                        "docdbsecretstore-secretstore" : {
                            "Type" : "secretstore",
                            "deployment:Unit" : "aws-docdb-secretstore",
                            "Engine" : "aws:secretsmanager"
                        }
                    }
                }
            },
            "Processors" : {
                "docdbsecretstore" : {
                    "ddb" : {
                        "Processor" : "db.t3.medium",
                        "MinCount" : 2,
                        "MaxCount" : 2,
                        "DesiredCount" : 2
                    }
                }
            },
            "TestCases" : {
                "docdbsecretstore" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "ddsCluster" : {
                                    "Name" : "ddsClusterXdbXdocdb",
                                    "Type" : "AWS::DocDB::DBCluster"
                                },
                                "ddsInstanceA1" : {
                                    "Name" : "ddsXdbXdocdbXaX1",
                                    "Type" : "AWS::DocDB::DBInstance"
                                },
                                "ddsInstanceA2" : {
                                    "Name" : "ddsXdbXdocdbXaX2",
                                    "Type" : "AWS::DocDB::DBInstance"
                                },
                                "rdsParameterGroup" : {
                                    "Name" : "ddsClusterParameterGroupXdbXdocdbXdocdb4X0",
                                    "Type" : "AWS::DocDB::DBClusterParameterGroup"
                                },
                                "secret" : {
                                    "Name" : "secretXdbXdocdbsecretstoreXRootCredentials",
                                    "Type" : "AWS::SecretsManager::Secret"
                                }
                            },
                            "Output" : [
                                "rdsXdbXdocdbsecretstoreXdns",
                                "rdsXdbXdocdbsecretstoreXport",
                                "secretXdbXdocdbsecretstoreXRootCredentialsXarn"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "SecretGeneration" : {
                                    "Path"  : "Resources.secretXdbXdocdbsecretstoreXRootCredentials.Properties.GenerateSecretString.SecretStringTemplate",
                                    "Value" : getJSON({"username": "root"})
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "docdbsecretstore" : {
                    "ddb" : {
                        "TestCases" : [ "docdbsecretstore" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]

    [#-- Maintenance Windows --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "db" : {
                    "Components" : {
                        "docdbmaintenance" : {
                            "Type" : "ddb",
                            "deployment:Unit" : "aws-docdb-maintenance",
                            "MaintenanceWindow": {
                                "DayOfTheWeek": "Saturday",
                                "TimeOfDay": "01:00",
                                "TimeZone": "AEST"
                            },
                            "EngineVersion" : "4.0",
                            "Port": "mongodb",
                            "Profiles" : {
                                "Testing" : [ "docdbmaintenance" ]
                            },
                            "GenerateCredentials" : {
                                "Enabled" : true,
                                "EncryptionScheme" : "kms"
                            }
                        }
                    }
                }
            },
            "Processors" : {
                "docdbmaintenance" : {
                    "ddb" : {
                        "Processor" : "db.t3.medium",
                        "MinCount" : 2,
                        "MaxCount" : 2,
                        "DesiredCount" : 2
                    }
                }
            },
            "TestCases" : {
                "docdbmaintenance" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "ddsCluster" : {
                                    "Name" : "ddsClusterXdbXdocdb",
                                    "Type" : "AWS::DocDB::DBCluster"
                                },
                                "ddsInstanceA1" : {
                                    "Name" : "ddsXdbXdocdbXaX1",
                                    "Type" : "AWS::DocDB::DBInstance"
                                },
                                "ddsInstanceA2" : {
                                    "Name" : "ddsXdbXdocdbXaX2",
                                    "Type" : "AWS::DocDB::DBInstance"
                                },
                                "rdsParameterGroup" : {
                                    "Name" : "ddsClusterParameterGroupXdbXdocdbXdocdb4X0",
                                    "Type" : "AWS::DocDB::DBClusterParameterGroup"
                                }
                            },
                            "Output" : [
                                "rdsXdbXdocdbmaintenanceXdns",
                                "rdsXdbXdocdbmaintenanceXport"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "MaintenanceWindow" : {
                                    "Path"  : "Resources.rdsXdbXdocdbmaintenance.Properties.PreferredMaintenanceWindow",
                                    "Value" : "Fri:15:00-Fri:15:30"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "docdbmaintenance" : {
                    "ddb" : {
                        "TestCases" : [ "docdbmaintenance" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]

    [#-- Backup Windows --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "db" : {
                    "Components" : {
                        "docdbbackup" : {
                            "Type" : "ddb",
                            "deployment:Unit" : "aws-docdb-backup",
                            "BackupWindow": {
                                "TimeOfDay": "01:00",
                                "TimeZone": "AEST"
                            },
                            "EngineVersion" : "4.0",
                            "Port": "mongodb",
                            "Profiles" : {
                                "Testing" : [ "docdbbackup" ]
                            },
                            "GenerateCredentials" : {
                                "Enabled" : true,
                                "EncryptionScheme" : "kms"
                            }
                        }
                    }
                }
            },
            "Processors" : {
                "docdbbackup" : {
                    "ddb" : {
                        "Processor" : "db.t3.medium",
                        "MinCount" : 2,
                        "MaxCount" : 2,
                        "DesiredCount" : 2
                    }
                }
            },
            "TestCases" : {
                "docdbbackup" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "ddsCluster" : {
                                    "Name" : "ddsClusterXdbXdocdb",
                                    "Type" : "AWS::DocDB::DBCluster"
                                },
                                "ddsInstanceA1" : {
                                    "Name" : "ddsXdbXdocdbXaX1",
                                    "Type" : "AWS::DocDB::DBInstance"
                                },
                                "ddsInstanceA2" : {
                                    "Name" : "ddsXdbXdocdbXaX2",
                                    "Type" : "AWS::DocDB::DBInstance"
                                },
                                "rdsParameterGroup" : {
                                    "Name" : "ddsClusterParameterGroupXdbXdocdbXdocdb4X0",
                                    "Type" : "AWS::DocDB::DBClusterParameterGroup"
                                }
                            },
                            "Output" : [
                                "rdsXdbXdocdbbackupXdns",
                                "rdsXdbXdocdbbackupXport"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "BackupWindow" : {
                                    "Path"  : "Resources.rdsXdbXdocdbbackup.Properties.PreferredBackupWindow",
                                    "Value" : "Fri:15:00-Fri:15:30"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "docdbbackup" : {
                    "ddb" : {
                        "TestCases" : [ "docdbbackup" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]
[/#macro]
