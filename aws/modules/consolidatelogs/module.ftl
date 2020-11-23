[#ftl]

[@addModule
    name="consolidatelogs"
    description="Solution-wide consolidation of logs into ops data bucket"
    provider=AWS_PROVIDER
    properties=[
        {
            "Names" : "namePrefix",
            "Type" : STRING_TYPE,
            "Description" : "A prefix appended to component names and deployment units to ensure uniquness",
            "Default" : ""
        },
        {
            "Names" : "deploymentProfile",
            "Type" : STRING_TYPE,
            "Description" : "The deployment profile id to enable log consolidation on.",
            "Mandatory" : true
        },
        {
            "Names" : "lambdaSourceUrl",
            "Type" : STRING_TYPE,
            "Description" : "A URL to the lambda zip package for sending alerts",
            "Default" : "https://github.com/hamlet-io/lambda-log-processors/releases/download/v1.0.2/cloudwatch-firehose.zip"
        },
        {
            "Names" : "lambdaSourceHash",
            "Type" : STRING_TYPE,
            "Description" : "A sha1 hash of the lambda image to validate the correct one",
            "Default" : "3a6b1ce462aaa203477044cfe83c66f128381434"
        },
        {
            "Names" : "tier",
            "Type" : STRING_TYPE,
            "Description" : "The tier to use to host the components",
            "Default" : "mgmt"
        }
    ]
/]

[#macro aws_module_consolidatelogs
    namePrefix
    deploymentProfile
    lambdaSourceUrl
    lambdaSourceHash
    tier]

    [@debug message="Entering Module: consolidate-logs" context=layerActiveData enabled=false /]

    [#local lambdaName = formatName(namePrefix + "cwlogslambda")]
    [#local datafeedName = formatName(namePrefix + "cwlogsdatafeed")]

    [@loadModule
        blueprint={
            "Tiers" : {
                tier : {
                    "Components" : {
                        datafeedName : {
                            "datafeed": {
                                "Instances": {
                                    "default": {
                                        "DeploymentUnits": [ datafeedName ]
                                    }
                                },
                                "Encrypted": true,
                                "Destination": {
                                    "Link": {
                                        "Tier": "mgmt",
                                        "Component": "baseline",
                                        "DataBucket": "opsdata",
                                        "Instance": "",
                                        "Version": ""
                                    }
                                },
                                "LogWatchers": {
                                    "app-all": {
                                        "LogFilter": "all-logs"
                                    }
                                },
                                "Profiles" : {
                                    "Logging" : "noforward"
                                },
                                "Bucket" : {
                                    "Prefix" : "CWLogs/Logs/",
                                    "ErrorPrefix" : "CWLogs/Errors/"
                                },
                                "Links": {
                                    "processor" : {
                                        "Tier" : tier,
                                        "Component" : lambdaName,
                                        "Function" : "processor",
                                        "Instance" : "",
                                        "Version" : "",
                                        "Role" : "invoke"
                                    }
                                }
                            }
                        },
                        lambdaName : {
                            "lambda": {
                                "Instances": {
                                    "default": {
                                        "DeploymentUnits": [ lambdaName ]
                                    }
                                },
                                "Image" : {
                                    "Source" : "url",
                                    "UrlSource" : {
                                        "Url" : lambdaSourceUrl,
                                        "ImageHash" : lambdaSourceHash
                                    }
                                },
                                "Functions": {
                                    "processor": {
                                        "RunTime": "python3.6",
                                        "MemorySize": 256,
                                        "Timeout": 300,
                                        "Handler": "src/run.lambda_handler",
                                        "PredefineLogGroup" : true,
                                        "Profiles" : {
                                            "Logging" : "noforward"
                                        },
                                        "Links": {
                                            "feed" : {
                                                "Tier" : tier,
                                                "Component" : datafeedName,
                                                "Instance" : "",
                                                "Version" : "",
                                                "Role" : "produce"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "LogFilters": {
                "all-logs": {
                    "Pattern": ""
                }
            },
            "LoggingProfiles" : {
                "consolidate" : {
                    "ForwardingRules": {
                        "store": {
                            "Filter": "all-logs",
                            "Links": {
                                "feed": {
                                    "Tier": tier,
                                    "Component": datafeedName,
                                    "Instance": "",
                                    "Version": ""
                                }
                            }
                        }
                    }
                },
                "noforward" : {
                    "ForwardingRules" : {
                    }
                }
            },
            "DeploymentProfiles" : {
                deploymentProfile : {
                    "Modes" : {
                        "*" : {
                            "*" : {
                                "Profiles" : {
                                    "Logging" : "consolidate"
                                }
                            },
                            "apigateway" : {
                                "AccessLogging" : {
                                    "Enabled" : true,
                                    "aws:KinesisFirehose" : true,
                                    "aws:KeepLogGroup" : true
                                },
                                "WAF" : {
                                    "Logging" : {
                                        "Enabled" : true
                                    }
                                }
                            },
                            "cdn" : {
                                "EnableLogging" : true,
                                "WAF" : {
                                    "Logging" : {
                                        "Enabled" : true
                                    }
                                }
                            },
                            "lb" : {
                                "Logs" : true,
                                "WAF" : {
                                    "Logging" : {
                                         "Enabled" : true
                                     }
                                 }
                            }
                        }
                    }
                }
            }
        }
    /]

    [#-- TODO(rossmurr4y): feature: add test case to the provider: log consolidation bucket exists --]
    [#-- TODO(rossmurr4y): feature: add test case to the provider: opsdata replication rule exists --]
    [#-- TODO(rossmurr4y): feature: add test case to the provider:  log processor exists --]
    [#-- TODO(rossmurr4y): feature: add test case to the provider: datafeed exists and uses log processor --]
    [#-- TODO(rossmurr4y): feature: add test case to the provider: mocked apigw exists and logs to a firehose --]
    [#-- TODO(rossmurr4y): feature: add test case to the provider: mocked LB exists and has loadbalancerattributes enabling logs --]
    [#-- TODO(rossmurr4y): feature: add test profile to module --]

[/#macro]
