[#ftl]

[@addModule
    name="consolidatelogs"
    description="Solution-wide consolidation of logs, intended for consumption by ElasticSearch."
    provider=AWS_PROVIDER
    properties=[
        {
            "Names" : "namePrefix",
            "Type" : STRING_TYPE,
            "Description" : "A prefix appended to component names and deployment units to ensure uniquness",
            "Default" : "log"
        },
        {
            "Names" : "deploymentProfile",
            "Type" : STRING_TYPE,
            "Description" : "The deployment profile id to enable log consolidation on."
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

    [#local lambdaName = formatName(namePrefix, "lambda")]
    [#local datafeedName = formatName(namePrefix, "datafeed")]

    [#local product = getActiveLayer(PRODUCT_LAYER_TYPE) ]
    [#local environment = getActiveLayer(ENVIRONMENT_LAYER_TYPE)]
    [#local segment = getActiveLayer(SEGMENT_LAYER_TYPE)]

    [#local namespace = formatName(product["Name"], environment["Name"], segment["Name"])]
    [#local lambdaSettingNamespace = formatName(namespace, lambdaName)]

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
                                "aws:WAFLogFeed": true,
                                "Links": {
                                    "processor" : {
                                        "Tier" : tier,
                                        "Component" : lambdaName,
                                        "Instance" : "",
                                        "Version" : "",
                                        "Function" : "processor",
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
                                        "MemorySize": 128,
                                        "Timeout": 30,
                                        "Handler": "src/run.lambda_handler",
                                        "Links": {
                                            "feed" : {
                                                "Tier" : tier,
                                                "Component" : datafeedName,
                                                "Instance" : "",
                                                "Version" : "",
                                                "Role" : "logwatcher"
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
                                "store": {
                                    "Tier": "mgmt",
                                    "Component": "baseline",
                                    "Instance": "",
                                    "Version": "",
                                    "DataBucket" : "opsdata",
                                    "Role" : "produce"
                                }
                            }
                        }
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
                                }
                            },
                            "cdn" : {
                                "EnableLogging" : true,
                                "WAF" : {
                                    "Profiles" : {
                                        "EnableLogging" : true,
                                        "Logging" : "consolidate"
                                    }
                                }
                            },
                            "lb" : {
                                "Logs" : true
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