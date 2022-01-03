[#ftl]

[@addModule
    name="runbook_rds_pgdump"
    description="Run a pgdump on a postgres db component and save the result locally"
    provider=AWS_PROVIDER
    properties=[
        {
            "Names" : "bastionLink",
            "Description" : "A Link to an ssh bastion host which can access the db component",
            "Mandatory" : true,
            "AttributeSet" : LINK_ATTRIBUTESET_TYPE
        },
        {
            "Names" : "dbLink",
            "Description" : "A link to the db component running postgres that the dump will be created from",
            "Mandatory" : true,
            "AttributeSet" : LINK_ATTRIBUTESET_TYPE
        }
    ]
/]

[#macro aws_module_runbook_rds_pgdump
        bastionLink
        dbLink ]

    [@loadModule
        blueprint={
            "Tiers" : {
                dbLink.Tier : {
                    "Components" : {
                        "${dbLink.Component}_pgdump" : {
                            "Description" : "Creates a pg_dump of the database and saves it to a local file path",
                            "Type" : "runbook",
                            "Engine" : "hamlet",
                            "Inputs" : {
                                "outputfilepath" : {
                                    "Type" : STRING_TYPE,
                                    "Description" : "The local file path to save the dump file to",
                                    "Mandatory" : true
                                }
                            },
                            "Steps" : {
                                "aws_login" : {
                                    "Priority" : 5,
                                    "Extensions" : [ "_runbook_get_provider_id" ],
                                    "Task" : {
                                        "Type" : "set_provider_credentials",
                                        "Parameters" : {
                                            "Account" : {
                                                "Value" : "__setting:ACCOUNT__"
                                            }
                                        }
                                    }
                                },
                                "ssh_key_decrypt" : {
                                    "Priority" : 10,
                                    "Extensions" : [ "_runbook_get_region" ],
                                    "Task" : {
                                        "Type" : "aws_decrypt_kms_ciphertext",
                                        "Parameters" : {
                                            "Ciphertext" : {
                                                "Value" : "__attribute:ssh_key:PRIVATE_KEY__"
                                            },
                                            "EncryptionScheme" : {
                                                "Value" : "__attribute:ssh_key:ENCRYPTION_SCHEME__"
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
                                        "ssh_key" : {
                                            "Tier" : "mgmt",
                                            "Component" : "baseline",
                                            "SubComponent" : "ssh",
                                            "Type" : "baselinekey"
                                        }
                                    }
                                },
                                "dburl_key_decrypt" : {
                                    "Priority" : 10,
                                    "Extensions" : [ "_runbook_get_region" ],
                                    "Task" : {
                                        "Type" : "aws_decrypt_kms_ciphertext",
                                        "Parameters" : {
                                            "Ciphertext" : {
                                                "Value" : "__attribute:db:URL__"
                                            },
                                            "EncryptionScheme" : {
                                                "Value" : "__attribute:db:ENCRYPTION_SCHEME__"
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
                                        "db" : dbLink
                                    }
                                },
                                "install_pgdump" : {
                                    "Priority" : 50,
                                    "Task" : {
                                        "Type" : "ssh_run_command",
                                        "Parameters" : {
                                            "Host" : {
                                                "Value" : "__attribute:bastion:IP_ADDRESS__"
                                            },
                                            "Username" : {
                                                "Value" : "ec2-user"
                                            },
                                            "SSHKey" : {
                                                "Value" : "__output:ssh_key_decrypt:result__"
                                            },
                                            "Command" : {
                                                "Value" : "which pg_dump || sudo amazon-linux-extras install postgresql13 -y"
                                            }
                                        }
                                    },
                                    "Links" : {
                                        "bastion" : bastionLink
                                    }
                                },
                                "run_pgdump" : {
                                    "Priority" : 75,
                                    "Task" : {
                                        "Type" : "ssh_run_command",
                                        "Parameters" : {
                                            "Host" : {
                                                "Value" : "__attribute:bastion:IP_ADDRESS__"
                                            },
                                            "Username" : {
                                                "Value" : "ec2-user"
                                            },
                                            "SSHKey" : {
                                                "Value" : "__output:ssh_key_decrypt:result__"
                                            },
                                            "Command" : {
                                                "Value" : "pg_dump -F c '__output:dburl_key_decrypt:result__' --file=/tmp/pg_dump_${dbLink.Tier}_${dbLink.Component}.dump"
                                            }
                                        }
                                    },
                                    "Links" : {
                                        "bastion" : bastionLink
                                    }
                                },
                                "copy_pgdump_local" : {
                                    "Priority" : 100,
                                    "Task" : {
                                        "Type" : "ssh_copy_file",
                                        "Parameters" : {
                                            "Host" : {
                                                "Value" : "__attribute:bastion:IP_ADDRESS__"
                                            },
                                            "Username" : {
                                                "Value" : "ec2-user"
                                            },
                                            "SSHKey" : {
                                                "Value" : "__output:ssh_key_decrypt:result__"
                                            },
                                            "Direction" : {
                                                "Value" : "RemoteToLocal"
                                            },
                                            "LocalPath" : {
                                                "Value" : "__input:outputfilepath__"
                                            },
                                            "RemotePath" : {
                                                "Value" : "/tmp/pg_dump_${dbLink.Tier}_${dbLink.Component}.dump"
                                            }
                                        }
                                    },
                                    "Links" : {
                                        "bastion" : bastionLink
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
