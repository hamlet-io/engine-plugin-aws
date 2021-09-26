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
        settingSets=[
            {
                "Type" : "Settings",
                "Scope" : "Products",
                "Namespace" : "mockedup-integration-aws-db-postgres-base",
                "Settings" : {
                    "MASTER_USERNAME" : "testUser",
                    "MASTER_PASSWORD" : "testPassword"
                }
            }
        ]
        blueprint={
            "Tiers" : {
                "db" : {
                    "Components" : {
                        "postgresdbbase" : {
                            "db" : {
                                "Instances" : {
                                    "default" : {
                                        "DeploymentUnits" : ["aws-db-postgres-base"]
                                    }
                                },
                                "Engine" : "postgres",
                                "EngineVersion" : "11",
                                "Profiles" : {
                                    "Testing" : [ "postgresdbbase" ]
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "postgresdbbase" : {
                    "OutputSuffix" : "template.json",
                    "Tools" : {
                       "CFNLint" : true
                    },
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
                                "securityGroupXdbXpostgresdbbase"
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
                            "db" : {
                                "Instances" : {
                                    "default" : {
                                        "DeploymentUnits" : ["aws-db-postgres-generated"]
                                    }
                                },
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
                }
            },
            "TestCases" : {
                "postgresdbgenerated" : {
                    "OutputSuffix" : "template.json",
                    "Tools" : {
                       "CFNLint" : true
                    },
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
                                    "Path"  : "Resources.securityGroupXdbXpostgresdbgenerated.Properties.Tags[10].Value",
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

    [#-- Maintenance Windows --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "db" : {
                    "Components" : {
                        "postgresdbmaintenance" : {
                            "db" : {
                                "Instances" : {
                                    "default" : {
                                        "DeploymentUnits" : ["aws-db-postgres-maintenance"]
                                    }
                                },
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
                }
            },
            "TestCases" : {
                "postgresdbmaintenance" : {
                    "OutputSuffix" : "template.json",
                    "Tools" : {
                       "CFNLint" : true
                    },
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
[/#macro]
