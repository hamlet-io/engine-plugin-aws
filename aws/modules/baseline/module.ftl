[#ftl]

[@addModule
    name="baseline"
    description="The baseline module for AWS which controls the base level resources required for all deployments"
    provider=AWS_PROVIDER
    properties=[]
/]

[#macro aws_module_baseline]

    [@loadModule
        blueprint={
            "Tiers" : {
                "mgmt": {
                    "Components" : {
                        "baseline": {
                            "baseline": {
                                "deployment:Unit": "baseline",
                                "DataBuckets": {
                                    "opsdata": {
                                        "Role": "operations",
                                        "Encryption": {
                                            "EncryptionSource": "LocalService"
                                        },
                                        "Lifecycles": {
                                            "flowlogs": {
                                                "Prefix": "VPCFlowLogs",
                                                "Expiration": "_flowlogs",
                                                "Offline": "_flowlogs"
                                            },
                                            "awslogs": {
                                                "Prefix": "AWSLogs",
                                                "Expiration": "_operations",
                                                "Offline": "_operations"
                                            },
                                            "cloudfront": {
                                                "Prefix": "CLOUDFRONTLogs",
                                                "Expiration": "_operations",
                                                "Offline": "_operations"
                                            },
                                            "docker": {
                                                "Prefix": "DOCKERLogs",
                                                "Expiration": "_operations",
                                                "Offline": "_operations"
                                            },
                                            "waf": {
                                                "Prefix": "WAF",
                                                "Expiration": "_operations",
                                                "Offline": "_operations"
                                            }
                                        },
                                        "Links": {
                                            "cf_key": {
                                                "Tier": "mgmt",
                                                "Component": "baseline",
                                                "Instance": "",
                                                "Version": "",
                                                "Key": "oai"
                                            }
                                        }
                                    },
                                    "appdata": {
                                        "Role": "appdata",
                                        "Lifecycles": {
                                            "global": {
                                                "Expiration": "_data",
                                                "Offline": "_data"
                                            }
                                        }
                                    }
                                },
                                "Keys": {
                                    "ssh": {
                                        "Engine": "ssh"
                                    },
                                    "cmk": {
                                        "Engine": "cmk",
                                        "Extensions": [
                                            "_cmk_s3_access",
                                            "_cmk_ses_access",
                                            "_cmk_cloudfront_access"
                                        ]
                                    },
                                    "oai": {
                                        "Engine": "oai"
                                    }
                                }
                            }
                        },
                        "baseline_kms-encrypt" : {
                            "Description" : "Encrypt a string or filepath with the baseline kms key",
                            "Type" : "runbook",
                            "Engine" : "hamlet",
                            "Inputs" : {
                                "Value" : {
                                    "Description" : "The value to encrypt",
                                    "Types" : [ "string" ],
                                    "Mandatory" : true
                                },
                                "EncryptionScheme" : {
                                    "Description" : "A scheme prefix to added to the result",
                                    "Types" : [ "string" ],
                                    "Default" : ""
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
                                "kms_encrypt" : {
                                    "Priority" : 100,
                                    "Extensions" : [ "_runbook_get_region" ],
                                    "Task" : {
                                        "Type" : "aws_kms_encrypt_value",
                                        "Parameters" : {
                                            "KeyArn" : {
                                                "Value" : "__attribute:key:ARN__"
                                            },
                                            "Value" : {
                                                "Value" : "__input:Value__"
                                            },
                                            "EncryptionScheme" : {
                                                "Value" : "__input:EncryptionScheme__"
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
                                        "key" : {
                                            "Tier" : "mgmt",
                                            "Component" : "baseline",
                                            "SubComponent" : "cmk",
                                            "Type" : "baselinekey"
                                        }
                                    }
                                },
                                "output" : {
                                    "Priority" : 120,
                                    "Extensions" : [ "_runbook_get_region" ],
                                    "Task" : {
                                        "Type" : "output_echo",
                                        "Parameters" : {
                                            "Value" : {
                                                "Value" : "__output:kms_encrypt:result__"
                                            }
                                        }
                                    },
                                    "Links" : {
                                        "key" : {
                                            "Tier" : "mgmt",
                                            "Component" : "baseline",
                                            "SubComponent" : "cmk",
                                            "Type" : "baselinekey"
                                        }
                                    }
                                }
                            }
                        },
                        "baseline_kms-decrypt" : {
                            "Description" : "Decrypt a base64 encoded kms ciphertext object",
                            "Type" : "runbook",
                            "Engine" : "hamlet",
                            "Inputs" : {
                                "Value" : {
                                    "Description" : "The base64 encoded kms ciphertext",
                                    "Types" : [ "string" ],
                                    "Mandatory" : true
                                },
                                "EncryptionScheme" : {
                                    "Description" : "If the value included an encryption scheme the scheme that has been used",
                                    "Types" : [ "string" ],
                                    "Default" : ""
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
                                "kms_decrypt" : {
                                    "Priority" : 100,
                                    "Extensions" : [ "_runbook_get_region" ],
                                    "Task" : {
                                        "Type" : "aws_kms_decrypt_ciphertext",
                                        "Parameters" : {
                                            "Ciphertext" : {
                                                "Value" : "__input:Value__"
                                            },
                                            "EncryptionScheme" : {
                                                "Value" : "__input:EncryptionScheme__"
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
                                    }
                                },
                                "output" : {
                                    "Priority" : 120,
                                    "Extensions" : [ "_runbook_get_region" ],
                                    "Task" : {
                                        "Type" : "output_echo",
                                        "Parameters" : {
                                            "Value" : {
                                                "Value" : "__output:kms_decrypt:result__"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "BaselineProfiles": {
                "default": {
                    "OpsData": "opsdata",
                    "AppData": "appdata",
                    "Encryption": "cmk",
                    "SSHKey": "ssh",
                    "CDNOriginKey": "oai"
                }
            }
        }
    /]
[/#macro]
