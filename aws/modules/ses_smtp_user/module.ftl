[#ftl]

[@addModule
    name="ses_smtp_user"
    description="Fixed user credentials that can be used for SMTP access to SES"
    provider=AWS_PROVIDER
    properties=[
        {
            "Names" : "tier",
            "Type" : STRING_TYPE,
            "Description" : "The tier the user will be part of",
            "Default" : "app"
        },
        {
            "Names" : "component",
            "Type" : STRING_TYPE,
            "Description" : "The name of the smtp user component",
            "Default" : "smtp_user"
        },
        {
            "Names" : "deploymentUnit",
            "Type" : STRING_TYPE,
            "Description" : "The deployment unit for the private bastion",
            "Default" : "smtp-user"
        },
        {
            "Names": "sesRegion",
            "Type" : STRING_TYPE,
            "Description" : "The SES region that will be used for sending emails",
            "Default" : "us-east-1"
        }
    ]
/]

[#macro aws_module_ses_smtp_user
            tier
            component
            deploymentUnit
            sesRegion ]

    [@loadModule
        blueprint={
            "Tiers" : {
                tier : {
                    "Components" : {
                        component: {
                            "Type" : "user",
                            "deployment:Unit": deploymentUnit,
                            "Extensions" : [
                                "_user_ses_smtp_permissions"
                            ],
                            "GenerateCredentials" : {
                                "EncryptionScheme" : "",
                                "Formats" : [ "system" ]
                            },
                            "Permissions" : {
                                "Decrypt": false,
                                "AppData": false,
                                "AsFile": false
                            }
                        },
                        "${component}_ses-password" : {
                            "Description" : "Generate a sig4 password for use with SES",
                            "Type" : "runbook",
                            "Engine" : "hamlet",
                            "Inputs" : {
                                "sesRegion" : {
                                    "Types" : "string",
                                    "Default" : sesRegion,
                                    "Values" : [
                                        "us-east-2",
                                        "us-east-1",
                                        "us-west-1",
                                        "us-west-2",
                                        "ap-south-1",
                                        "ap-northeast-3",
                                        "ap-northeast-2",
                                        "ap-southeast-1",
                                        "ap-southeast-2",
                                        "ap-northeast-1",
                                        "ca-central-1",
                                        "eu-central-1",
                                        "eu-west-1",
                                        "eu-west-2",
                                        "eu-west-3",
                                        "eu-north-1",
                                        "sa-east-1",
                                        "us-gov-west-1"
                                    ]
                                }
                            },
                            "Steps" : {
                                "aws_login" : {
                                    "Priority" : 5,
                                    "Extensions" : [ "_runbook_get_provider_id" ],
                                    "Task" : {
                                        "Type" : "set_provider_credentials",
                                        "Parameters" : {
                                            "AccountId" : {
                                                "Value" : "__setting:ACCOUNT__"
                                            }
                                        }
                                    }
                                },
                                "decrypt_user_password" : {
                                    "Priority" : 10,
                                    "Extensions" : [ "_runbook_get_region" ],
                                    "Task" : {
                                        "Type" : "aws_kms_decrypt_ciphertext",
                                        "Parameters" : {
                                            "Ciphertext" : {
                                                "Value" : "__attribute:user:SECRET_KEY__"
                                            },
                                            "EncryptionScheme" : {
                                                "Value" : ""
                                            },
                                            "AWSAccessKeyId" : {
                                                "Value" : "__output:aws_login:aws_access_key_id__"
                                            },
                                            "AWSSecretAccessKey" : {
                                                "Value" : "__output:aws_login:aws_secret_access_key__"
                                            },
                                            "AWSSessionToken" : {
                                                "Value" : "__output:aws_login:aws_session_token__"
                                            }
                                        }
                                    },
                                    "Links" : {
                                        "user" : {
                                            "Tier" : tier,
                                            "Component" : component,
                                            "Type" : "user"
                                        }
                                    }
                                },
                                "ses_password" : {
                                    "Priority" : 50,
                                    "Task" : {
                                        "Type" : "aws_ses_smtp_password",
                                        "Parameters" : {
                                            "SESRegion" : {
                                                "Value" : "__input:sesRegion__"
                                            },
                                            "AWSSecretAccessKey" : {
                                                "Value" : "__output:decrypt_user_password:result__"
                                            }
                                        }
                                    }
                                },
                                "output_echo" : {
                                    "Priority" : 100,
                                    "Task": {
                                        "Type" : "output_echo",
                                        "Parameters" : {
                                            "Format": {
                                                "Value": "json"
                                            },
                                            "Value" : {
                                                "Value" : getJSON({
                                                    "host" : "email-smtp.__input:sesRegion__.amazonaws.com",
                                                    "port" : 587,
                                                    "username" : "__attribute:user:ACCESS_KEY__",
                                                    "password" : "__output:ses_password:smtp_password__"
                                                })
                                            }
                                        }
                                    },
                                    "Links" : {
                                        "user" : {
                                            "Tier" : tier,
                                            "Component" : component,
                                            "Type" : "user"
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
