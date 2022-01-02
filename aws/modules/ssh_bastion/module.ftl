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
                            "Permissions": {
                                "Decrypt": true
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
                                        "Properties" : {
                                            "AccountId" : {
                                                "Source" : "Setting",
                                                "source:Setting" : {
                                                    "Name" : "ACCOUNT"
                                                }
                                            }
                                        }
                                    }
                                },
                                "ssh_key_decrypt" : {
                                    "Priority" : 10,
                                    "Extensions" : [ "_runbook_get_region" ],
                                    "Task" : {
                                        "Type" : "aws_decrypt_kms_ciphertext",
                                        "Properties" : {
                                            "Ciphertext" : {
                                                "Source" : "Attribute",
                                                "source:Attribute" : {
                                                    "LinkId" : "ssh_key",
                                                    "Name" : "PRIVATE_KEY"
                                                }
                                            },
                                            "EncryptionScheme" : {
                                                "Source" : "Attribute",
                                                "source:Attribute" : {
                                                    "LinkId" : "ssh_key",
                                                    "Name" : "ENCRYPTION_SCHEME"
                                                }
                                            },
                                            "AWSAccessKeyId" : {
                                                "Source" : "Output",
                                                "source:Output" : {
                                                    "StepId" : "aws_login",
                                                    "Name" : "aws_access_key_id"
                                                }
                                            },
                                            "AWSSecretAccessKey" : {
                                                "Source" : "Output",
                                                "source:Output" : {
                                                    "StepId" : "aws_login",
                                                    "Name" : "aws_secret_access_key"
                                                }
                                            },
                                            "AWSSessionToken" : {
                                                "Source" : "Output",
                                                "source:Output" : {
                                                    "StepId" : "aws_login",
                                                    "Name" : "aws_session_token"
                                                }
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
                                        "Type" : "start_ssh_shell",
                                        "Properties" : {
                                            "Host" : {
                                                "Source" : "Attribute",
                                                "source:Attribute" : {
                                                    "LinkId" : "bastion",
                                                    "Name" : "IP_ADDRESS"
                                                }
                                            },
                                            "Username" : {
                                                "Source" : "Fixed",
                                                "source:Fixed" : {
                                                    "Value" : "ec2-user"
                                                }
                                            },
                                            "SSHKey" : {
                                                "Source" : "Output",
                                                "source:Output" : {
                                                    "StepId" : "ssh_key_decrypt",
                                                    "Name" : "result"
                                                }
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
