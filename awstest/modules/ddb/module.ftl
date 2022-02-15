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
                            },
                            "Settings" : {
                                "MASTER_USERNAME" : {
                                    "Value" : "testUser"
                                },
                                "MASTER_PASSWORD" : {
                                    "Value" : "testPassword"
                                }
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
                                    "Name" : "ddsClusterXdbXdocdbbase",
                                    "Type" : "AWS::DocDB::DBCluster"
                                },
                                "ddsInstanceA1" : {
                                    "Name" : "ddsXdbXdocdbbaseXaX1",
                                    "Type" : "AWS::DocDB::DBInstance"
                                },
                                "ddsParameterGroup" : {
                                    "Name" : "ddsClusterParameterGroupXdbXdocdbbaseXdocdb4X0",
                                    "Type" : "AWS::DocDB::DBClusterParameterGroup"
                                }
                            },
                            "Output" : [
                                "ddsClusterXdbXdocdbbaseXdns",
                                "ddsXdbXdocdbbaseXaX1Xport",
                                "securityGroupXdbXdocdbbase"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "DocDBEngineVersion" : {
                                    "Path"  : "Resources.ddsClusterXdbXdocdbbase.Properties.EngineVersion",
                                    "Value" : "4.0"
                                },
                                "ParameterGroupVersion" : {
                                    "Path" : "Resources.ddsClusterParameterGroupXdbXdocdbbaseXdocdb4X0.Properties.Family",
                                    "Value" : "docdb4.0"
                                }
                            },
                            "NotEmpty" : [
                                "Resources.ddsXdbXdocdbbaseXaX1.Properties.DBInstanceClass",
                                "Resources.ddsClusterXdbXdocdbbase.Properties.DBClusterIdentifier"
                            ]
                        }
                    },
                    "Tools": {
                        "cfn-lint": {
                            "IgnoreChecks": [ "E3035", "E3036", "E3003" ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "docdbbase" : {
                    "ddb" : {
                        "TestCases" : [ "docdbbase" ]
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
                            "DeletionPolicy": "Delete",
                            "UpdateReplacePolicy": "Delete",
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
                            },
                            "Settings" : {
                                "MASTER_USERNAME" : {
                                    "Value" : "testUser"
                                },
                                "MASTER_PASSWORD" : {
                                    "Value" : "testPassword"
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
                                    "Name" : "ddsClusterXdbXdocdbsecretstore",
                                    "Type" : "AWS::DocDB::DBCluster"
                                },
                                "ddsInstanceA1" : {
                                    "Name" : "ddsXdbXdocdbsecretstoreXaX1",
                                    "Type" : "AWS::DocDB::DBInstance"
                                },
                                "rdsParameterGroup" : {
                                    "Name" : "ddsClusterParameterGroupXdbXdocdbsecretstoreXdocdb4X0",
                                    "Type" : "AWS::DocDB::DBClusterParameterGroup"
                                },
                                "secret" : {
                                    "Name" : "secretXdbXdocdbsecretstoreXRootCredentials",
                                    "Type" : "AWS::SecretsManager::Secret"
                                }
                            },
                            "Output" : [
                                "ddsClusterXdbXdocdbsecretstoreXdns",
                                "ddsClusterXdbXdocdbsecretstoreXport",
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
                    },
                    "Tools": {
                        "cfn-lint": {
                            "IgnoreChecks": [ "E3035", "E3036", "E3003" ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "docdbsecretstore" : {
                    "ddb" : {
                        "TestCases" : [ "docdbsecretstore" ]
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
                            "DeletionPolicy": "Retain",
                            "UpdateReplacePolicy": "Retain",
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
                            },
                            "Settings" : {
                                "MASTER_USERNAME" : {
                                    "Value" : "testUser"
                                },
                                "MASTER_PASSWORD" : {
                                    "Value" : "testPassword"
                                }
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
                                    "Name" : "ddsClusterXdbXdocdbmaintenance",
                                    "Type" : "AWS::DocDB::DBCluster"
                                },
                                "ddsInstanceA1" : {
                                    "Name" : "ddsXdbXdocdbmaintenanceXaX1",
                                    "Type" : "AWS::DocDB::DBInstance"
                                },
                                "rdsParameterGroup" : {
                                    "Name" : "ddsClusterParameterGroupXdbXdocdbmaintenanceXdocdb4X0",
                                    "Type" : "AWS::DocDB::DBClusterParameterGroup"
                                }
                            },
                            "Output" : [
                                "ddsClusterXdbXdocdbmaintenanceXdns",
                                "ddsClusterXdbXdocdbmaintenanceXport"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "MaintenanceWindow" : {
                                    "Path"  : "Resources.ddsClusterXdbXdocdbmaintenance.Properties.PreferredMaintenanceWindow",
                                    "Value" : "Fri:15:00-Fri:15:30"
                                }
                            }
                        }
                    },
                    "Tools": {
                        "cfn-lint": {
                            "IgnoreChecks": [ "E3035", "E3036", "E3003" ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "docdbmaintenance" : {
                    "ddb" : {
                        "TestCases" : [ "docdbmaintenance" ]
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
                            "Backup": {
                                "BackupWindow": {
                                    "TimeOfDay": "01:00",
                                    "TimeZone": "AEST"
                                }
                            },
                            "EngineVersion" : "4.0",
                            "Port": "mongodb",
                            "Profiles" : {
                                "Testing" : [ "docdbbackup" ]
                            },
                            "Settings" : {
                                "MASTER_USERNAME" : {
                                    "Value" : "testUser"
                                },
                                "MASTER_PASSWORD" : {
                                    "Value" : "testPassword"
                                }
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
                                    "Name" : "ddsClusterXdbXdocdbbackup",
                                    "Type" : "AWS::DocDB::DBCluster"
                                },
                                "ddsInstanceA1" : {
                                    "Name" : "ddsXdbXdocdbbackupXaX1",
                                    "Type" : "AWS::DocDB::DBInstance"
                                },
                                "rdsParameterGroup" : {
                                    "Name" : "ddsClusterParameterGroupXdbXdocdbbackupXdocdb4X0",
                                    "Type" : "AWS::DocDB::DBClusterParameterGroup"
                                }
                            },
                            "Output" : [
                                "ddsClusterXdbXdocdbbackupXdns",
                                "ddsClusterXdbXdocdbbackupXport",
                                "ddsXdbXdocdbbackupXaX1Xport"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "BackupWindow" : {
                                    "Path"  : "Resources.ddsClusterXdbXdocdbbackup.Properties.PreferredBackupWindow",
                                    "Value" : "15:00-15:30"
                                }
                            }
                        }
                    },
                    "Tools": {
                        "cfn-lint": {
                            "IgnoreChecks": [ "E3035", "E3036", "E3003" ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "docdbbackup" : {
                    "ddb" : {
                        "TestCases" : [ "docdbbackup" ]
                    }
                }
            }
        }
    /]
[/#macro]
