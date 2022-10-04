[#ftl]

[@addModule
    name="datacatalog"
    description="Testing module for the aws datacatalog component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_datacatalog ]

    [#-- Data Stream Source --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "datacatalogbase": {
                            "Type" : "datacatalog",
                            "deployment:Unit": "aws-datacatalog",
                            "Profiles" : {
                                "Testing" : [ "datacatalogbase" ]
                            },
                            "Tables" : {
                                "base" : {
                                    "Source" : {
                                        "Link" : {
                                            "Tier": "app",
                                            "Component": "datacatalogbase-s3"
                                        }
                                    },
                                    "Layout": {
                                        "Columns": {
                                            "date": {
                                                "Type": "date"
                                            },
                                            "size": {
                                                "Type": "bigint"
                                            }
                                        }
                                    },
                                    "Format": {
                                        "Input": "org.apache.hadoop.mapred.TextInputFormat",
                                        "Output": "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat",
                                        "Serialisation": {
                                            "Library": "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
                                        }
                                    }
                                }
                            }
                        },
                        "datacatalogbase-s3":{
                            "Type": "s3",
                            "deployment:Unit": "aws-datacatalog"
                        }
                    }
                }
            },
            "TestCases" : {
                "datacatalogbase" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "Firehose" : {
                                    "Name" : "gluedatabaseXappXdatacatalogbase",
                                    "Type" : "AWS::Glue::Database"
                                },
                                "Stream" : {
                                    "Name" : "gluetableXappXdatacatalogbaseXbase",
                                    "Type" : "AWS::Glue::Table"
                                }
                            },
                            "Output" : [
                                "gluedatabaseXappXdatacatalogbase"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "EnsureSubComponentNameUsed" : {
                                    "Path"  : "Resources.gluetableXappXdatacatalogbaseXbase.Properties.TableInput.Name",
                                    "Value" : "base"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "datacatalogbase" : {
                    "datacatalog" : {
                        "TestCases" : [ "datacatalogbase" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]

[/#macro]
