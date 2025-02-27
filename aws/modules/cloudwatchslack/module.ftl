[#ftl]

[@addModule
    name="alarmslack"
    description="Sends slack notifications based on cloudwatch alarms"
    provider=AWS_PROVIDER
    properties=[
        {
            "Names" : "slackChannel",
            "Type" : STRING_TYPE,
            "Description" : "The slack channel to send alerts to",
            "Mandatory" : true
        },
        {
            "Names" : "webHookUrl",
            "Type" : STRING_TYPE,
            "Description" : "The slack incoming webhook URL to use - Encryption is recommended",
            "Mandatory" : true
        },
        {
            "Names" : "alertSeverity",
            "Type" : STRING_TYPE,
            "Description" : "The lowest severity alerts to include in notifications",
            "Default" : "info"
        },
        {
            "Names" : "alertProfile",
            "Type" : STRING_TYPE,
            "Description" : "The alert profile id to use for enabling notifications",
            "Default" : "default"
        },
        {
            "Names" : "kmsPrefix",
            "Type" : STRING_TYPE,
            "Description" : "The KMS prefix used for encrypted values",
            "Default" : "base64:"
        },
        {
            "Names" : "lambdaSourceUrl",
            "Type" : STRING_TYPE,
            "Description" : "A URL to the lambda zip package for sending alerts",
            "Default" : "https://github.com/hamlet-io/lambda-cloudwatch-slack/releases/download/v1.1.0/cloudwatch-slack.zip"
        },
        {
            "Names" : "lambdaSourceHash",
            "Type" : STRING_TYPE,
            "Description" : "A sha1 hash of the lambda image to ensure its the right one",
            "Default" : "8f194db4f6ed2b826387112df144f188451ba6db"
        },
        {
            "Names" : "namePrefix",
            "Type" : STRING_TYPE,
            "Description" : "A prefix appended to component names and deployment units to ensure uniquness",
            "Default" : "alarmslack"
        },
        {
            "Names" : "tier",
            "Type" : STRING_TYPE,
            "Description" : "The tier to use to host the components",
            "Default" : "mgmt"
        },
        {
            "Names" : "extension",
            "Type" : STRING_TYPE,
            "Description" : "The extension to define businessAlerts",
            "Default" : "_mgmtalarms"
        }
    ]
/]

[#macro aws_module_alarmslack
            slackChannel
            webHookUrl
            kmsPrefix
            lambdaSourceUrl
            lambdaSourceHash
            namePrefix
            tier
            alertSeverity
            alertProfile 
            extension ]

    [#local topicName = formatName(namePrefix, "topic" )]
    [#local lambdaName = formatName(namePrefix, "lambda" )]

    [#local product = getActiveLayer(PRODUCT_LAYER_TYPE) ]
    [#local environment = getActiveLayer(ENVIRONMENT_LAYER_TYPE)]
    [#local segment = getActiveLayer(SEGMENT_LAYER_TYPE)]

    [#local namespace = formatName(product["Name"], environment["Name"], segment["Name"])]
    [#local lambdaSettingNamespace = formatName(namespace, lambdaName)]

    [@loadModule
        settingSets=[
            {
                "Type" : "Settings",
                "Scope" : "Products",
                "Namespace" : lambdaSettingNamespace,
                "Settings" : {
                    "SLACK_HOOK_URL" : webHookUrl,
                    "KMS_PREFIX" : kmsPrefix,
                    "SLACK_CHANNEL" : slackChannel,
                    "ENVIRONMENT" : environment["Name"]
                }
            }
        ]
        blueprint={
            "Tiers" : {
                tier : {
                    "Components" : {
                        topicName : {
                            "Type" : "topic",
                            "deployment:Unit" : topicName,
                            "deployment:Priority" : 50,
                            "Subscriptions" : {
                                "slack" : {
                                    "Links" : {
                                        "lambda" : {
                                            "Tier" : tier,
                                            "Component" : lambdaName,
                                            "Function" : "send"
                                        }
                                    }
                                }
                            }
                        },
                        lambdaName : {
                            "Type" : "lambda",
                            "deployment:Unit" : lambdaName,
                            "Functions" : {
                                "send" : {
                                    "Handler" : "cloudwatch-slack/lambda_function.lambda_handler",
                                    "Extensions": [
                                        extension
                                    ],
                                    "RunTime" : "python3.9",
                                    "MemorySize" : 128,
                                    "Timeout" : 15,
                                    "VPCAccess" : false,
                                    "PredefineLogGroup" : true,
                                    "Links" : {
                                        "alerts" : {
                                            "Tier" : tier,
                                            "Component" : topicName,
                                            "Direction" : "inbound",
                                            "Role" : "invoke"
                                        }
                                    }
                                }
                            },
                            "Image" : {
                                "Source" : "url",
                                "UrlSource" : {
                                    "Url" : lambdaSourceUrl,
                                    "ImageHash" : lambdaSourceHash
                                }
                            }
                        }
                    }
                }
            },
            "AlertRules" : {
                "SlackNotify" : {
                    "Severity" : alertSeverity,
                    "Destinations" : {
                        "Links" : {
                            "alarm" : {
                                "Tier" : tier,
                                "Component" : topicName,
                                "Instance" : "",
                                "Version" : ""
                            }
                        }
                    }
                }
            },
            "AlertProfiles" : {
                alertProfile : {
                    "Rules" : ["SlackNotify" ]
                }
            }
        }
    /]
[/#macro]
