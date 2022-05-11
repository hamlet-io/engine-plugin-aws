[#ftl]

[@addModule
    name="db"
    description="Testing module for the aws db component"
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
                        "postgresdbbase" : {
                            "Type" : "db",
                            "deployment:Unit" : "aws-db",
                            "Engine" : "postgres",
                            "EngineVersion" : "11",
                            "Profiles" : {
                                "Testing" : [ "postgresdbbase" ]
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
            "TestCases" : {
                "postgresdbbase" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "rdsInstance" : {
                                    "Name" : "rdsXdbXpostgresdbbase",
                                    "Type" : "AWS::RDS::DBInstance"
                                },
                                "rdsOptionGroup" : {
                                    "Name" : "rdsOptionGroupXdbXpostgresdbbaseXpostgres11",
                                    "Type" : "AWS::RDS::OptionGroup"
                                },
                                "rdsParameterGroup" : {
                                    "Name" : "rdsParameterGroupXdbXpostgresdbbaseXpostgres11",
                                    "Type" : "AWS::RDS::DBParameterGroup"
                                }
                            },
                            "Output" : [
                                "rdsXdbXpostgresdbbaseXdns",
                                "rdsXdbXpostgresdbbaseXport",
                                "securityGroupXrdsXdbXpostgresdbbase"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "RDSEngine" : {
                                    "Path"  : "Resources.rdsXdbXpostgresdbbase.Properties.Engine",
                                    "Value" : "postgres"
                                },
                                "RDSEngineVersion" : {
                                    "Path"  : "Resources.rdsXdbXpostgresdbbase.Properties.EngineVersion",
                                    "Value" : "11"
                                },
                                "OptionGroupVersion" : {
                                    "Path" : "Resources.rdsOptionGroupXdbXpostgresdbbaseXpostgres11.Properties.MajorEngineVersion",
                                    "Value" : "11"
                                },
                                "ParameterGroupVersion" : {
                                    "Path" : "Resources.rdsParameterGroupXdbXpostgresdbbaseXpostgres11.Properties.Family",
                                    "Value" : "postgres11"
                                }
                            },
                            "NotEmpty" : [
                                "Resources.rdsXdbXpostgresdbbase.Properties.DBInstanceClass"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "postgresdbbase" : {
                    "db" : {
                        "TestCases" : [ "postgresdbbase" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]

    [#-- Minor Version database setup --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "db" : {
                    "Components" : {
                        "postgresdbminorversion" : {
                            "Type" : "db",
                            "deployment:Unit" : "aws-db",
                            "Engine" : "postgres",
                            "EngineVersion" : "12",
                            "EngineMinorVersion" : "4",
                            "Profiles" : {
                                "Testing" : [ "postgresdbminorversion" ]
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
            "TestCases" : {
                "postgresdbminorversion" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "rdsInstance" : {
                                    "Name" : "rdsXdbXpostgresdbminorversion",
                                    "Type" : "AWS::RDS::DBInstance"
                                },
                                "rdsOptionGroup" : {
                                    "Name" : "rdsOptionGroupXdbXpostgresdbminorversionXpostgres12",
                                    "Type" : "AWS::RDS::OptionGroup"
                                },
                                "rdsParameterGroup" : {
                                    "Name" : "rdsParameterGroupXdbXpostgresdbminorversionXpostgres12",
                                    "Type" : "AWS::RDS::DBParameterGroup"
                                }
                            },
                            "Output" : [
                                "rdsXdbXpostgresdbminorversionXdns",
                                "rdsXdbXpostgresdbminorversionXport",
                                "securityGroupXrdsXdbXpostgresdbminorversion"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "RDSEngine" : {
                                    "Path"  : "Resources.rdsXdbXpostgresdbminorversion.Properties.Engine",
                                    "Value" : "postgres"
                                },
                                "RDSEngineVersion" : {
                                    "Path"  : "Resources.rdsXdbXpostgresdbminorversion.Properties.EngineVersion",
                                    "Value" : "12.4"
                                },
                                "OptionGroupVersion" : {
                                    "Path" : "Resources.rdsOptionGroupXdbXpostgresdbminorversionXpostgres12.Properties.MajorEngineVersion",
                                    "Value" : "12"
                                },
                                "ParameterGroupVersion" : {
                                    "Path" : "Resources.rdsParameterGroupXdbXpostgresdbminorversionXpostgres12.Properties.Family",
                                    "Value" : "postgres12"
                                }
                            },
                            "NotEmpty" : [
                                "Resources.rdsXdbXpostgresdbminorversion.Properties.DBInstanceClass"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "postgresdbminorversion" : {
                    "db" : {
                        "TestCases" : [ "postgresdbminorversion" ]
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
                        "postgresdbgenerated" : {
                            "Type" : "db",
                            "deployment:Unit" : "aws-db",
                            "Engine" : "postgres",
                            "EngineVersion" : "11",
                            "Profiles" : {
                                "Testing" : [ "postgresdbgenerated" ]
                            },
                            "GenerateCredentials" : {
                                "Enabled" : true,
                                "EncryptionScheme" : "kms"
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "postgresdbgenerated" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "rdsInstance" : {
                                    "Name" : "rdsXdbXpostgresdbgenerated",
                                    "Type" : "AWS::RDS::DBInstance"
                                }
                            },
                            "Output" : [
                                "rdsXdbXpostgresdbgeneratedXdns",
                                "rdsXdbXpostgresdbgeneratedXport"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "SecurityGroupTagName" : {
                                    "Path"  : "Resources.securityGroupXrdsXdbXpostgresdbgenerated.Properties.Tags[10].Value",
                                    "Value" : "mockedup-integration-database-postgresdbgenerated"
                                },
                                "SubnetGroupTagName" : {
                                    "Path"  : "Resources.rdsSubnetGroupXdbXpostgresdbgenerated.Properties.Tags[10].Value",
                                    "Value" : "mockedup-integration-database-postgresdbgenerated"
                                },
                                "DbTagName" : {
                                    "Path"  : "Resources.rdsXdbXpostgresdbgenerated.Properties.Tags[10].Value",
                                    "Value" : "mockedup-integration-database-postgresdbgenerated"
                                },
                                "OptionGroupTagName" : {
                                    "Path"  : "Resources.rdsOptionGroupXdbXpostgresdbgeneratedXpostgres11.Properties.Tags[10].Value",
                                    "Value" : "mockedup-integration-database-postgresdbgenerated"
                                },
                                "ParameterGroupTagName" : {
                                    "Path"  : "Resources.rdsParameterGroupXdbXpostgresdbgeneratedXpostgres11.Properties.Tags[10].Value",
                                    "Value" : "mockedup-integration-database-postgresdbgenerated"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "postgresdbgenerated" : {
                    "db" : {
                        "TestCases" : [ "postgresdbgenerated" ]
                    }
                }
            }
        }
    /]

    [#-- RDS instance events --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "db" : {
                    "Components" : {
                        "postgresdbevent-topic": {
                            "Type" : "topic",
                            "deployment:Unit" : "aws-db"
                        },
                        "postgresdbevent" : {
                            "Type" : "db",
                            "deployment:Unit" : "aws-db",
                            "Engine" : "postgres",
                            "EngineVersion" : "11",
                            "Profiles" : {
                                "Testing" : [ "postgresdbevent" ]
                            },
                            "GenerateCredentials" : {
                                "Enabled" : true,
                                "EncryptionScheme" : "kms"
                            },
                            "Links": {
                                "rds_events": {
                                    "Tier": "db",
                                    "Component": "postgresdbevent-topic",
                                    "Instance": "default",
                                    "Version": "",
                                    "Role": "publish configuration change,failure,deletion"
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "postgresdbevent" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "rdsInstanceEvent" : {
                                    "Name" : "rdsXdbXpostgresdbeventXinstanceXrdsXevents",
                                    "Type" : "AWS::RDS::EventSubscription"
                                }
                            },
                            "Output" : [
                                "rdsXdbXpostgresdbeventXinstanceXrdsXevents"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "EventTypeName" : {
                                    "Path"  : "Resources.rdsXdbXpostgresdbeventXinstanceXrdsXevents.Properties.SourceType",
                                    "Value" : "db-instance"
                                },
                                "EventCategories0" : {
                                    "Path"  : "Resources.rdsXdbXpostgresdbeventXinstanceXrdsXevents.Properties.EventCategories[0]",
                                    "Value" : "configuration change"
                                },
                                "EventCategories1" : {
                                    "Path"  : "Resources.rdsXdbXpostgresdbeventXinstanceXrdsXevents.Properties.EventCategories[1]",
                                    "Value" : "failure"
                                },
                                "EventCategories2" : {
                                    "Path"  : "Resources.rdsXdbXpostgresdbeventXinstanceXrdsXevents.Properties.EventCategories[2]",
                                    "Value" : "deletion"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "postgresdbevent" : {
                    "db" : {
                        "TestCases" : [ "postgresdbevent" ]
                    }
                }
            }
        }
    /]

    [#-- Secret store creds --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "db" : {
                    "Components" : {
                        "postgresdbsecretstore" : {
                            "Type" : "db",
                            "deployment:Unit" : "aws-db",
                            "Engine" : "postgres",
                            "EngineVersion" : "11",
                            "Profiles" : {
                                "Testing" : [ "postgresdbsecretstore" ]
                            },
                            "rootCredential:Source" : "SecretStore",
                            "rootCredential:SecretStore" : {
                                "Link" : {
                                    "Tier" : "db",
                                    "Component": "postgresdbsecretstore-secretstore"
                                }
                            }
                        },
                        "postgresdbsecretstore-secretstore" : {
                            "Type" : "secretstore",
                            "deployment:Unit" : "aws-db",
                            "Engine" : "aws:secretsmanager"
                        }
                    }
                }
            },
            "TestCases" : {
                "postgresdbsecretstore" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "rdsInstance" : {
                                    "Name" : "rdsXdbXpostgresdbsecretstore",
                                    "Type" : "AWS::RDS::DBInstance"
                                },
                                "secret" : {
                                    "Name" : "secretXdbXpostgresdbsecretstoreXRootCredentials",
                                    "Type" : "AWS::SecretsManager::Secret"
                                }
                            },
                            "Output" : [
                                "rdsXdbXpostgresdbsecretstoreXdns",
                                "rdsXdbXpostgresdbsecretstoreXport",
                                "secretXdbXpostgresdbsecretstoreXRootCredentialsXarn"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "SecretGeneration" : {
                                    "Path"  : "Resources.secretXdbXpostgresdbsecretstoreXRootCredentials.Properties.GenerateSecretString.SecretStringTemplate",
                                    "Value" : getJSON({"username": "root"})
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "postgresdbsecretstore" : {
                    "db" : {
                        "TestCases" : [ "postgresdbsecretstore" ]
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
                        "postgresdbmaintenance" : {
                            "Type" : "db",
                            "deployment:Unit" : "aws-db",
                            "MaintenanceWindow": {
                                "DayOfTheWeek": "Saturday",
                                "TimeOfDay": "01:00",
                                "TimeZone": "AEST"
                            },
                            "Engine" : "postgres",
                            "EngineVersion" : "11",
                            "Profiles" : {
                                "Testing" : [ "postgresdbmaintenance" ]
                            },
                            "GenerateCredentials" : {
                                "Enabled" : true,
                                "EncryptionScheme" : "kms"
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "postgresdbmaintenance" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "rdsInstance" : {
                                    "Name" : "rdsXdbXpostgresdbmaintenance",
                                    "Type" : "AWS::RDS::DBInstance"
                                }
                            },
                            "Output" : [
                                "rdsXdbXpostgresdbmaintenanceXdns",
                                "rdsXdbXpostgresdbmaintenanceXport"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "MaintenanceWindow" : {
                                    "Path"  : "Resources.rdsXdbXpostgresdbmaintenance.Properties.PreferredMaintenanceWindow",
                                    "Value" : "Fri:15:00-Fri:15:30"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "postgresdbmaintenance" : {
                    "db" : {
                        "TestCases" : [ "postgresdbmaintenance" ]
                    }
                }
            }
        }
    /]

    [#-- cluster database setup --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "db" : {
                    "Components" : {
                        "postgresdbcluster-topic": {
                            "Type" : "topic",
                            "deployment:Unit" : "aws-db"
                        },
                        "postgresdbcluster" : {
                            "Type" : "db",
                            "deployment:Unit" : "aws-db",
                            "Engine" : "aurora-postgresql",
                            "Port": "postgresql",
                            "EngineVersion" : "11",
                            "Cluster" : {
                                "Parameters": {
                                    "tls" : {
                                        "Name" : "rds.force_ssl",
                                        "Value" : true
                                    }
                                }
                            },
                            "Profiles" : {
                                "Testing" : [ "postgresdbcluster" ],
                                "Processor" : "postgresdbcluster"
                            },
                            "Settings" : {
                                "MASTER_USERNAME" : {
                                    "Value" : "testUser"
                                },
                                "MASTER_PASSWORD" : {
                                    "Value" : "testPassword"
                                }
                            },
                            "Links": {
                                "rds_events": {
                                    "Tier": "db",
                                    "Component": "postgresdbcluster-topic",
                                    "Instance": "default",
                                    "Version": "",
                                    "Role": "publish"
                                }
                            }
                        }
                    }
                }
            },
            "Processors" : {
                "postgresdbcluster" : {
                    "db" : {
                        "Processor" : "db.t3.medium",
                        "MinCount" : 2,
                        "MaxCount" : 2,
                        "DesiredCount" : 2
                    }
                }
            },
            "TestCases" : {
                "postgresdbcluster" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "rdsCluster" : {
                                    "Name" : "rdsClusterXdbXpostgresdbcluster",
                                    "Type" : "AWS::RDS::DBCluster"
                                },
                                "rdsInstanceA1" : {
                                    "Name" : "rdsXdbXpostgresdbclusterXaX1",
                                    "Type" : "AWS::RDS::DBInstance"
                                },
                                "rdsInstanceA2" : {
                                    "Name" : "rdsXdbXpostgresdbclusterXaX2",
                                    "Type" : "AWS::RDS::DBInstance"
                                },
                                "rdsOptionGroup" : {
                                    "Name" : "rdsOptionGroupXdbXpostgresdbclusterXauroraXpostgresql11",
                                    "Type" : "AWS::RDS::OptionGroup"
                                },
                                "rdsParameterGroup" : {
                                    "Name" : "rdsParameterGroupXdbXpostgresdbclusterXauroraXpostgresql11",
                                    "Type" : "AWS::RDS::DBParameterGroup"
                                },
                                "rdsClusterParameterGroup" : {
                                    "Name" : "rdsClusterParameterGroupXdbXpostgresdbclusterXauroraXpostgresql11",
                                    "Type" : "AWS::RDS::DBClusterParameterGroup"
                                },
                                "rdsClusterEvent" : {
                                    "Name" : "rdsClusterXdbXpostgresdbclusterXclusterXrdsXevents",
                                    "Type" : "AWS::RDS::EventSubscription"
                                },
                                "rdsClusterInstanceEvent" : {
                                    "Name" : "rdsXdbXpostgresdbclusterXaX1XinstanceXrdsXevents",
                                    "Type" : "AWS::RDS::EventSubscription"
                                }
                            },
                            "Output" : [
                                "rdsClusterXdbXpostgresdbclusterXreaddns",
                                "rdsXdbXpostgresdbclusterXaX2Xdns",
                                "securityGroupXrdsClusterXdbXpostgresdbcluster",
                                "rdsClusterXdbXpostgresdbclusterXclusterXrdsXevents"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "RDSEngine" : {
                                    "Path"  : "Resources.rdsClusterXdbXpostgresdbcluster.Properties.Engine",
                                    "Value" : "aurora-postgresql"
                                },
                                "RDSEngineVersion" : {
                                    "Path"  : "Resources.rdsClusterXdbXpostgresdbcluster.Properties.EngineVersion",
                                    "Value" : "11"
                                },
                                "OptionGroupVersion" : {
                                    "Path" : "Resources.rdsOptionGroupXdbXpostgresdbclusterXauroraXpostgresql11.Properties.MajorEngineVersion",
                                    "Value" : "11"
                                },
                                "ParameterGroupVersion" : {
                                    "Path" : "Resources.rdsParameterGroupXdbXpostgresdbclusterXauroraXpostgresql11.Properties.Family",
                                    "Value" : "aurora-postgresql11"
                                },
                                "EventTypeNameC" : {
                                    "Path"  : "Resources.rdsClusterXdbXpostgresdbclusterXclusterXrdsXevents.Properties.SourceType",
                                    "Value" : "db-cluster"
                                },
                                "EventTypeNameI" : {
                                    "Path"  : "Resources.rdsXdbXpostgresdbclusterXaX1XinstanceXrdsXevents.Properties.SourceType",
                                    "Value" : "db-instance"
                                }
                            },
                            "NotEmpty" : [
                                "Resources.rdsXdbXpostgresdbclusterXaX1.Properties.DBInstanceClass",
                                "Resources.rdsXdbXpostgresdbclusterXaX2.Properties.DBInstanceClass"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "postgresdbcluster" : {
                    "db" : {
                        "TestCases" : [ "postgresdbcluster" ]
                    }
                }
            }
        }
    /]
[/#macro]
