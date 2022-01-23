[#ftl]

[@addModule
    name="ssh_bastion"
    description="Public bastion server with ssh support"
    provider=AWS_PROVIDER
    properties=[
        {
            "Names" : "tier",
            "Type" : STRING_TYPE,
            "Description" : "The tier to use to host the private bastion",
            "Default" : "mgmt"
        },
        {
            "Names" : "component",
            "Type" : STRING_TYPE,
            "Description" : "The component to use to host the private bastion",
            "Default" : "ssh"
        },
        {
            "Names" : "deploymentUnit",
            "Type" : STRING_TYPE,
            "Description" : "The deployment unit for the private bastion",
            "Default" : "ssh"
        },
        {
            "Names" : "activeDeploymentMode",
            "Type" : STRING_TYPE,
            "Description" : "The name of the deployment Mode to use to activate the bastion",
            "Default" : "activebastion"
        },
        {
            "Names" : "IPAddressGroups",
            "Type" : ARRAY_OF_STRING_TYPE,
            "Description" : "A list of IPAddressGroups that can access the bastion host",
            "Default" : []
        }
    ]
/]

[#macro aws_module_ssh_bastion
            tier
            component
            deploymentUnit
            activeDeploymentMode
            IPAddressGroups]

    [@loadModule
        blueprint={
            "Tiers" : {
                tier : {
                    "Components" : {
                        component: {
                            "Type" : "bastion",
                            "deployment:Unit": deploymentUnit,
                            "IPAddressGroups" : IPAddressGroups,
                            "AutoScaling": {
                                "DetailedMetrics": false,
                                "ActivityCooldown": 180,
                                "MinUpdateInstances": 0,
                                "AlwaysReplaceOnUpdate": false
                            },
                            "Profiles" : {
                                "Deployment" : [ "${tier}_${component}_active" ]
                            }
                        },
                        "${component}_ssh-session" : {
                            "Description" : "Starts an interactive SSH session with the bastion host using the baseline ssh key",
                            "Type" : "runbook",
                            "Engine" : "hamlet",
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
                                "ssh_key_decrypt" : {
                                    "Priority" : 10,
                                    "Extensions" : [ "_runbook_get_region" ],
                                    "Task" : {
                                        "Type" : "aws_kms_decrypt_ciphertext",
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
                                "start_ssh_shell" : {
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
                                                "Value" : "/bin/bash"
                                            }
                                        }
                                    },
                                    "Links" : {
                                        "bastion" : {
                                            "Tier" : tier,
                                            "Component" : component
                                        }
                                    }
                                }
                            }
                        },
                        "${component}_bastion-session" : {
                            "Description" : "Starts an ssh session with any instance in the vpc via the bastion",
                            "Type" : "runbook",
                            "Engine" : "hamlet",
                            "Steps" : {
                                "aws_login" : {
                                    "Priority" : 5,
                                    "Extensions" : [ "_runbook_get_provider_id" ],
                                    "Task" : {
                                        "Type" : "set_provider_credentials",
                                        "Properties" : {
                                            "AccountId" : {
                                                "Value" : "__setting:ACCOUNT__"
                                            }
                                        }
                                    }
                                },
                                "ssh_key_decrypt" : {
                                    "Priority" : 10,
                                    "Extensions" : [ "_runbook_get_region" ],
                                    "Task" : {
                                        "Type" : "aws_kms_decrypt_ciphertext",
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
                                "select_instance" : {
                                    "Priority" : 20,
                                    "Extensions" : [ "_runbook_get_region", "_runbook_get_vpc_id" ],
                                    "Task" : {
                                        "Type" : "aws_ec2_select_instance",
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
                                        "host" : {
                                            "Tier" : tier,
                                            "Component" : component
                                        }
                                    }
                                },
                                "get_instance_ip" : {
                                    "Priority" : 30,
                                    "Extensions" : [ "_runbook_get_ec2_ip" ],
                                    "Task" : {
                                        "Type" : "bash_run_command"
                                    }
                                },
                                "start_ssh_shell" : {
                                    "Priority" : 50,
                                    "Task" : {
                                        "Type" : "ssh_run_command",
                                        "Parameters" : {
                                            "Host" : {
                                                "Value" : "__output:get_instance_ip:result__"
                                            },
                                            "Username" : {
                                                "Value" : "ec2-user"
                                            },
                                            "SSHKey" : {
                                                "Value" : "__output:ssh_key_decrypt:result__"
                                            },
                                            "Command" : {
                                                "Value" : "/bin/bash"
                                            },
                                            "BastionHost" : {
                                                "Value" : "__attribute:bastion:IP_ADDRESS__"
                                            },
                                            "BastionUsername" : {
                                                "Value" : "ec2-user"
                                            },
                                            "BastionSSHKey" : {
                                                "Value" : "__output:ssh_key_decrypt:result__"
                                            }
                                        }
                                    },
                                    "Links" : {
                                        "bastion" : {
                                            "Tier" : tier,
                                            "Component" : component
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "NetworkProfiles": {
                "default": {
                    "BaseSecurityGroup": {
                        "Links": {
                            "sshBastion": {
                                "Tier": tier,
                                "Component": component,
                                "Instance": "",
                                "Version": "",
                                "Direction": "inbound",
                                "Role": "networkacl"
                            }
                        }
                    }
                }
            },
            "DeploymentProfiles" : {
                "${tier}_${component}_active" : {
                    "Modes" : {
                        activeDeploymentMode : {
                            "bastion" : {
                                "Active" : true
                            }
                        }
                    }
                }
            },
            "DeploymentModes" : {
                activeDeploymentMode : {
                    "Operations": [ "update" ],
                    "Membership": "priority",
                    "Priority": {
                        "GroupFilter": ".*",
                        "Order": "LowestFirst"
                    }
                }
            }
        }
    /]
[/#macro]
