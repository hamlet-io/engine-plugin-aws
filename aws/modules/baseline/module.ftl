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
                        },
                        "baseline_push-image": {
                            "Type": "runbook",
                            "Engine": "hamlet",
                            "Inputs" : {
                                "ImagePath" : {
                                    "Description" : "Path to the image to push",
                                    "Types" : [ "string" ]
                                },
                                "DockerImage": {
                                    "Description" : "Local docker iamge to push",
                                    "Types" : [ "string" ]
                                },
                                "Reference" : {
                                    "Description" : "Unique reference for this image",
                                    "Types" : [ "string" ],
                                    "Mandatory" : true
                                },
                                "Tag" : {
                                    "Description" : "A human friednly tag to apply to the image",
                                    "Types" : [ "string" ],
                                    "Default" : ""
                                },
                                "Tier" : {
                                    "Description" : "Tier id of the component to assign the image to",
                                    "Types" : [ "string" ],
                                    "Mandatory" : true
                                },
                                "Component" : {
                                    "Description" : "Component id of the component to assign the image to",
                                    "Types" : [ "string" ],
                                    "Mandatory" : true
                                },
                                "Instance" : {
                                    "Description" : "Instance Id of the component to assign the image to",
                                    "Types" : [ "string" ],
                                    "Default" : ""
                                },
                                "Instance" : {
                                    "Description" : "Instance Id of the component to assign the image to",
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
                                "zip_stage_path" : {
                                    "Priority" : 40,
                                    "Extensions" : [
                                        "_runbook_registry_type_condition"
                                    ],
                                    "Conditions" : {
                                        "registry_type" : {
                                            "Value": "s3",
                                            "Match": "Equals"
                                        }
                                    },
                                    "Task" : {
                                        "Type" : "file_temp_directory",
                                        "Parameters" : {}
                                    },
                                    "Links" : {
                                        "image" : {
                                            "Tier": "__input:Tier__",
                                            "Component": "__input:Component__",
                                            "Instance": "__input:Instance__",
                                            "Version": "__input:Version__"
                                        }
                                    }
                                },
                                "zip_path" : {
                                    "Priority": 50,
                                    "Extensions" : [
                                        "_runbook_registry_type_condition",
                                        "_runbook_registry_object_filename"
                                    ],
                                    "Conditions" : {
                                        "registry_type" : {
                                            "Value": "s3",
                                            "Match": "Equals"
                                        }
                                    },
                                    "Task" : {
                                        "Type" : "file_zip_path",
                                        "Parameters" : {
                                            "SourcePath" : {
                                                "Value": "__input:ImagePath__"
                                            }
                                        }
                                    },
                                    "Links" : {
                                        "image" : {
                                            "Tier": "__input:Tier__",
                                            "Component": "__input:Component__",
                                            "Instance": "__input:Instance__",
                                            "Version": "__input:Version__"
                                        }
                                    }
                                },
                                "registry_s3_push" : {
                                    "Priority" : 100,
                                    "Extensions" : [
                                        "_runbook_get_region",
                                        "_runbook_registry_destination_object",
                                        "_runbook_registry_type_condition"
                                    ],
                                    "Conditions" : {
                                        "registry_type" : {
                                            "Value": "s3",
                                            "Match": "Equals"
                                        }
                                    },
                                    "Task" : {
                                        "Type": "aws_s3_upload_object",
                                        "Parameters" : {
                                            "BucketName" : {
                                                "Value" : "__context:Environment.IMAGE_REGISTRY_BUCKET_NAME__"
                                            },
                                            "LocalPath" : {
                                                "Value" : "__output:zip_path:destination_path__"
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
                                        "image" : {
                                            "Tier": "__input:Tier__",
                                            "Component": "__input:Component__",
                                            "Instance": "__input:Instance__",
                                            "Version": "__input:Version__"
                                        }
                                    }
                                },
                                "registry_ecr_login" : {
                                    "Priority" : 50,
                                    "Conditions" : {
                                        "registry_type" : {
                                            "Value": "docker",
                                            "Match": "Equals"
                                        }
                                    },
                                    "Extensions" : [
                                        "_runbook_get_region",
                                        "_runbook_get_provider_id",
                                        "_runbook_registry_type_condition"
                                    ],
                                    "Task" : {
                                        "Type": "aws_ecr_docker_login",
                                        "Parameters" : {
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
                                        "image" : {
                                            "Tier": "__input:Tier__",
                                            "Component": "__input:Component__",
                                            "Instance": "__input:Instance__",
                                            "Version": "__input:Version__"
                                        }
                                    }
                                },
                                "registry_docker_push" : {
                                    "Priority" : 100,
                                    "Conditions" : {
                                        "registry_type" : {
                                            "Value": "docker",
                                            "Match": "Equals"
                                        }
                                    },
                                    "Extensions" : [
                                        "_runbook_registry_type_condition"
                                        "_runbook_registry_destination_image"
                                    ],
                                    "Task" : {
                                        "Type": "docker_push_image",
                                        "Parameters" : {
                                            "SourceImage" : {
                                                "Value" : "__input:DockerImage__"
                                            }
                                        }
                                    },
                                    "Links" : {
                                        "image" : {
                                            "Tier": "__input:Tier__",
                                            "Component": "__input:Component__",
                                            "Instance": "__input:Instance__",
                                            "Version": "__input:Version__"
                                        }
                                    }
                                },
                                "registry_docker_push_tag" : {
                                    "Priority" : 100,
                                    "Conditions" : {
                                        "registry_type" : {
                                            "Value": "docker",
                                            "Match": "Equals"
                                        },
                                        "tag_image" :{
                                            "Value": "",
                                            "Match": "NotEquals",
                                            "Test": "__input:Tag__"
                                        }
                                    },
                                    "Extensions" : [
                                        "_runbook_registry_type_condition"
                                        "_runbook_registry_destination_image_tag"
                                    ],
                                    "Task" : {
                                        "Type": "docker_push_image",
                                        "Parameters" : {
                                            "SourceImage" : {
                                                "Value" : "__input:DockerImage__"
                                            }
                                        }
                                    },
                                    "Links" : {
                                        "image" : {
                                            "Tier": "__input:Tier__",
                                            "Component": "__input:Component__",
                                            "Instance": "__input:Instance__",
                                            "Version": "__input:Version__"
                                        }
                                    }
                                },
                                "cmdb_write_reference" : {
                                    "Priority" : 200,
                                    "Extensions" : [
                                        "_runbook_image_reference_output",
                                        "_runbook_district_context"
                                    ],
                                    "Task": {
                                        "Type" : "cmdb_write_stack_output"
                                    },
                                    "Links" : {
                                        "image" : {
                                            "Tier": "__input:Tier__",
                                            "Component": "__input:Component__",
                                            "Instance": "__input:Instance__",
                                            "Version": "__input:Version__"
                                        }
                                    }
                                },
                                "output_result" : {
                                    "Priority" : 900,
                                    "Extensions" : [ "_runbook_image_push_result" ],
                                    "Task" : {
                                        "Type" : "output_echo",
                                        "Parameters" : {
                                            "Format" : {
                                                "Value" : "json"
                                            }
                                        }
                                    },
                                    "Links" : {
                                        "image" : {
                                            "Tier": "__input:Tier__",
                                            "Component": "__input:Component__",
                                            "Instance": "__input:Instance__",
                                            "Version": "__input:Version__"
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
