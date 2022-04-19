[#ftl]

[@addModule
    name="cache"
    description="Testing module for the aws cache component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_cache  ]

    [#-- Base --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "cachebase": {
                            "Type": "cache",
                            "deployment:Unit": "aws-cache",
                            "Profiles" : {
                                "Testing" : [ "cachebase" ]
                            },
                            "Engine": "redis",
                            "EngineVersion": "5.0.0",
                            "Alerts": {
                                "HighCPUUsage": {
                                    "Description": "Redis cache under high CPU load",
                                    "Name": "HighCPUUsage",
                                    "Metric": "EngineCPUUtilization",
                                    "Threshold": 90,
                                    "Severity": "error",
                                    "Statistic": "Average",
                                    "Periods": 2
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "cachebase" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "cacheCluster" : {
                                    "Name" : "cacheXappXcachebase",
                                    "Type" : "AWS::ElastiCache::CacheCluster"
                                },
                                "alarm" : {
                                    "Name" : "alarmXcacheXappXcachebaseXHighCPUUsage",
                                    "Type" : "AWS::CloudWatch::Alarm"
                                },
                                "securityGroup" : {
                                    "Name" : "securityGroupXcacheXappXcachebase",
                                    "Type" : "AWS::EC2::SecurityGroup"
                                }
                            },
                            "Output" : [
                                "cacheXappXcachebaseXport",
                                "cacheXappXcachebase",
                                "cacheXappXcachebaseXdns",
                                "alarmXcacheXappXcachebaseXHighCPUUsage"
                            ]
                        },
                        "JSON": {
                            "Match": {
                                "cacheTags" : {
                                    "Path"  : "Resources.cacheXappXcachebase.Properties.Tags[10].Value",
                                    "Value" : "mockedup-integration-application-cachebase"
                                },
                                "securityGroupTags" : {
                                    "Path"  : "Resources.securityGroupXcacheXappXcachebase.Properties.Tags[10].Value",
                                    "Value" : "mockedup-integration-application-cachebase"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "cachebase" : {
                    "cache" : {
                        "TestCases" : [ "cachebase" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]

    [#-- Maintenance Window --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "cachemaintenance": {
                            "cache": {
                                "Type": "cache",
                                "deployment:Unit": "aws-cache",
                                "Profiles" : {
                                    "Testing" : [ "cachemaintenance" ]
                                },
                                "Engine": "redis",
                                "EngineVersion": "5.0.0",
                                "MaintenanceWindow": {
                                    "DayOfTheWeek": "Saturday",
                                    "TimeOfDay": "1:30",
                                    "TimeZone": "AEST"
                                }
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "cachemaintenance" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "cacheCluster" : {
                                    "Name" : "cacheXappXcachemaintenance",
                                    "Type" : "AWS::ElastiCache::CacheCluster"
                                }
                            }
                        },
                        "JSON" : {
                            "Match" : {
                                "MaintenanceWindowDefined" : {
                                    "Path"  : "Resources.cacheXappXcachemaintenance.Properties.PreferredMaintenanceWindow",
                                    "Value" : "fri:15:30-fri:16:30"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "cachemaintenance" : {
                    "cache" : {
                        "TestCases" : [ "cachemaintenance" ]
                    }
                }
            }
        }
    /]
[/#macro]
