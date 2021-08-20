[#ftl]

[@addModule
    name="cache"
    description="Testing module for the aws cache component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_cache  ]

    [#-- Base cache --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "queue": {
                            "MultiAZ": false,
                            "cache": {
                                "Instances": {
                                    "default": {
                                        "Versions": {
                                            "v1": {
                                                "DeploymentUnits": [
                                                    "aws-queue-base"
                                                ]
                                            }
                                        }
                                    }
                                },
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
                }
            },
            "TestCases" : {
                "cachebase" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "cacheCluster" : {
                                    "Name" : "cacheXappXqueueXv1",
                                    "Type" : "AWS::ElastiCache::CacheCluster"
                                },
                                "alarm" : {
                                    "Name" : "alarmXcacheXappXqueueXv1XHighCPUUsage",
                                    "Type" : "AWS::CloudWatch::Alarm"
                                },
                                "securityGroup" : {
                                    "Name" : "securityGroupXcacheXappXqueueXv1",
                                    "Type" : "AWS::EC2::SecurityGroup"
                                }
                            },
                            "Output" : [
                                "cacheXappXqueueXv1Xport",
                                "cacheXappXqueueXv1",
                                "cacheXappXqueueXv1Xdns",
                                "alarmXcacheXappXqueueXv1XHighCPUUsage"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "cachebase" : {
                    "cache" : {
                        "TestCases" : [ "cachebase" ]
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
                        "queue": {
                            "MultiAZ": false,
                            "cache": {
                                "Instances": {
                                    "default": {
                                        "Versions": {
                                            "v1": {
                                                "DeploymentUnits": [
                                                    "aws-queue-maintenance"
                                                ]
                                            }
                                        }
                                    }
                                },
                                "Profiles" : {
                                    "Testing" : [ "cachemaintenance" ]
                                },
                                "Engine": "redis",
                                "EngineVersion": "5.0.0",
                                "MaintenanceWindow": {
                                    "DayOfTheWeek": "Saturday",
                                    "TimeOfDay": "1:30",
                                    "TimeZone": "AEST"
                                },
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
                }
            },
            "TestCases" : {
                "cachemaintenance" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "cacheCluster" : {
                                    "Name" : "cacheXappXqueueXv1",
                                    "Type" : "AWS::ElastiCache::CacheCluster"
                                },
                                "securityGroup" : {
                                    "Name" : "securityGroupXcacheXappXqueueXv1",
                                    "Type" : "AWS::EC2::SecurityGroup"
                                }
                            }
                        },
                        "JSON" : {
                            "Match" : {
                                "cacheMaintenanceWindow" : {
                                    "Path"  : "Resources.cacheXappXqueueXv1.Properties.PreferredMaintenanceWindow",
                                    "Value" : "fri:15:30-fri:16:30"
                                },
                                "cacheClusterTags" : {
                                    "Path"  : "Resources.cacheXappXqueueXv1.Properties.Tags[10].Value",
                                    "Value" : "mockedup-integration-application-queue-v1"
                                },
                                "securityGroupTags" : {
                                    "Path"  : "Resources.securityGroupXcacheXappXqueueXv1.Properties.Tags[10].Value",
                                    "Value" : "mockedup-integration-application-queue-v1"
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
