[#ftl]

[@addModule
    name="ses_mail_sender"
    description="General helper runbooks to manage S3 buckets"
    provider=AWS_PROVIDER
    properties=[
        {
            "Names" : "tier",
            "Type" : STRING_TYPE,
            "Description" : "The tier the user will be part of",
            "Default" : "msg"
        },
        {
            "Names" : "componentPrefix",
            "Type" : STRING_TYPE,
            "Description" : "The name of the smtp user component",
            "Default" : "mail"
        },
        {
            "Names" : "deploymentUnitPrefix",
            "Type" : STRING_TYPE,
            "Description" : "The deployment unit for the private bastion",
            "Default" : "mail"
        },
        {
            "Names" : "logToOps",
            "Type" : BOOLEAN_TYPE,
            "Description" : "Send all events to S3 in the OpsData Bucket",
            "Default" : true
        },
        {
            "Names" : "bounceAddresses",
            "Type" : ARRAY_OF_STRING_TYPE,
            "Description": "A set of email addresses that should be sent bounce/complaint events",
            "Default" : []
        },
        {
            "Names" : "senderAddress",
            "Type" : STRING_TYPE,
            "Description" : "The email address to use when sending emails",
            "Default" : "mailer@__attribute:mta:MAIL_DOMAIN__"
        }
    ]
/]

[#macro aws_module_ses_mail_sender tier componentPrefix deploymentUnitPrefix logToOps bounceAddresses senderAddress ]

    [@loadModule
        blueprint={
            "Tiers" : {
                tier: {
                    "Components": {
                        "${componentPrefix}-relay": {
                            "Type": "mta",
                            "Direction": "send",
                            "deployment:Unit": "${deploymentUnitPrefix}-relay",
                            "Certificate": {},
                            "Rules": {
                                "log": {
                                    "Action": "log",
                                    "EventTypes": [
                                        "reject",
                                        "bounce",
                                        "complaint",
                                        "delivery",
                                        "send"
                                    ],
                                    "Conditions": {
                                        "Senders": [""]
                                    },
                                    "Links": {
                                        "mail_topic": {
                                            "Tier": tier,
                                            "Component": "${componentPrefix}-topic",
                                            "Version": ""
                                        }
                                    }
                                }
                            }
                        },
                        "${componentPrefix}-topic": {
                            "Type": "topic",
                            "Encrypted" : true,
                            "deployment:Unit": "${deploymentUnitPrefix}-topic",
                            "Links" : {
                                "mail_relay": {
                                    "Tier": tier,
                                    "Component": "${componentPrefix}-relay",
                                    "Direction": "inbound",
                                    "Role": "invoke"
                                }
                            },
                            "Subscriptions": {
                                "forward": {
                                    "RawMessageDelivery": true,
                                    "Links": {
                                        "mail_relay": {
                                            "Enabled": false
                                        },
                                        "notify_queue": {
                                            "Tier": tier,
                                            "Component": "${componentPrefix}-queue",
                                            "Instance": "notify"
                                        },
                                        "events_queue": {
                                            "Tier": tier,
                                            "Component": "${componentPrefix}-queue",
                                            "Instance": "events"
                                        }
                                    }
                                }
                            }
                        },
                        "${componentPrefix}-queue" : {
                            "Type": "sqs",
                            "deployment:Unit": "${deploymentUnitPrefix}-queue",
                            "DeadLetterQueue": {
                                "Enabled": true,
                                "MaxReceives": 5
                            },
                            "Encryption": {
                                "Enabled": true
                            },
                            "Instances": {
                                "notify": {},
                                "events": {}
                            },
                            "Links": {
                                "topic": {
                                    "Tier": tier,
                                    "Component": "${componentPrefix}-topic",
                                    "Instance": "",
                                    "Direction": "inbound",
                                    "Role": "invoke"
                                }
                            }
                        },
                        "${componentPrefix}-handler": {
                            "Type": "lambda",
                            "deployment:Unit": "${deploymentUnitPrefix}-handler",
                            "Functions": {
                                "notify": {
                                    "RunTime": "python3.9",
                                    "Memory": 128,
                                    "Encrypted": true,
                                    "Handler": "index.lambda_handler",
                                    "Extensions": ["_lambda_ses_mail_sender_notify"],
                                    "PredefineLogGroup": true,
                                    "Image": {
                                        "Source": "extension",
                                        "source:extension": {
                                            "CommentCharacters": "#",
                                            "IncludeRunId": true
                                        }
                                    },
                                    "Settings" : {
                                        "SENDER_ADDRESS" : {
                                            "Value": senderAddress
                                        },
                                        "BOUNCE_ADDRESSES":{
                                            "Value": bounceAddresses?join(",")
                                        }
                                    },
                                    "Links": {
                                        "mta": {
                                            "Tier": tier,
                                            "Component": "${componentPrefix}-relay",
                                            "Instance": "",
                                            "Version": ""
                                        },
                                        "queue": {
                                            "Tier": tier,
                                            "Component": "${componentPrefix}-queue",
                                            "Instance": "notify",
                                            "Role": "event"
                                        }
                                    }
                                },
                                "events": {
                                    "RunTime": "python3.9",
                                    "Memory": 128,
                                    "Encrypted": true,
                                    "Handler": "index.lambda_handler",
                                    "Extensions": ["_lambda_ses_mail_sender_eventlog"],
                                    "PredefineLogGroup": true,
                                    "Image": {
                                        "Source": "extension",
                                        "source:extension": {
                                            "CommentCharacters": "#",
                                            "IncludeRunId": true
                                        }
                                    },
                                    "Settings" : {
                                        "S3_URL" : {
                                            "Value": logToOps?then("s3://__baseline:OpsData:NAME__", "")
                                        }
                                    },
                                    "Links": {
                                        "queue": {
                                            "Tier": tier,
                                            "Component": "${componentPrefix}-queue",
                                            "Instance": "events",
                                            "Role": "event"
                                        },
                                        "baseline_ops": {
                                            "Enabled" : logToOps,
                                            "Tier": tier,
                                            "Component": "baseline",
                                            "SubComponent": "opsdata",
                                            "Role": "produce"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    /]
[/#macro]
