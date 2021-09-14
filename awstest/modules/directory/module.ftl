[#ftl]

[@addModule
    name="directory"
    description="Testing module for the aws directory component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_directory  ]

    [#-- Base Simple directory --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "directorysimplebase":{
                            "directory": {
                                "Instances": {
                                    "default": {
                                        "deployment:Unit": "aws-directorysimplebase"
                                    }
                                },
                                "Engine": "Simple",
                                "Size": "Small",
                                "Profiles" : {
                                    "Testing" : [ "directorysimplebase" ]
                                },
                                "HostName" : {
                                    "IncludeInHost" : {
                                        "Product" : false,
                                        "Environment" : true,
                                        "Segment" : false,
                                        "Tier" : false,
                                        "Component" : false,
                                        "Instance" : true,
                                        "Version" : false,
                                        "Host" : true
                                    },
                                    "Host" : "directorysimple",
                                    "Qualifiers" : {
                                        "prod" : {
                                            "IncludeInHost" : {
                                                "Environment" : false,
                                                "Instance" : true
                                            }
                                        }
                                    }
                                },
                                "IPAddressGroups": [ "_global" ],
                                "RootCredentials" : {
                                    "SecretStore" : {
                                        "Tier" : "app",
                                        "Component" : "directorysimplesecretstore",
                                        "Instance" : "",
                                        "Version" :""
                                    }
                                }
                            }
                        },
                        "directorysimplesecretstore" : {
                            "secretstore" : {
                                "Instances" : {
                                    "default" : {
                                        "deployment:Unit" : "aws-directorysimple-secretstore"
                                    }
                                },
                                "Engine" : "aws:secretsmanager"
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "directorysimplebase" : {
                    "OutputSuffix" : "template.json",
                    "Tools" : {
                       "CFNLint" : true
                    },
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "queueHost" : {
                                    "Name" : "directoryXappXdirectorysimplebase",
                                    "Type" : "AWS::DirectoryService::SimpleAD"
                                },
                                "securityGroup" : {
                                    "Name" : "securityGroupXdirectoryXappXdirectorysimplebase",
                                    "Type" : "AWS::EC2::SecurityGroup"
                                },
                                "rootSecret" : {
                                    "Name" : "secretXappXdirectorysimplebaseXroot",
                                    "Type" : "AWS::SecretsManager::Secret"
                                }
                            },
                            "Output" : [
                                "directoryXappXdirectorysimplebaseXip",
                                "securityGroupXdirectoryXappXdirectorysimplebase",
                                "secretXappXdirectorysimplebaseXroot"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "directorysimplebase" : {
                    "directory" : {
                        "TestCases" : [ "directorysimplebase" ]
                    }
                }
            }
        }
    /]

    [#-- Base AD directory --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "directoryadbase":{
                            "directory": {
                                "Instances": {
                                    "default": {
                                        "deployment:Unit": "aws-directoryadbase"
                                    }
                                },
                                "Engine": "ActiveDirectory",
                                "Size": "Small",
                                "Profiles" : {
                                    "Testing" : [ "directoryadbase" ]
                                },
                                "HostName" : {
                                    "IncludeInHost" : {
                                        "Product" : false,
                                        "Environment" : true,
                                        "Segment" : false,
                                        "Tier" : false,
                                        "Component" : false,
                                        "Instance" : true,
                                        "Version" : false,
                                        "Host" : true
                                    },
                                    "Host" : "directoryad",
                                    "Qualifiers" : {
                                        "prod" : {
                                            "IncludeInHost" : {
                                                "Environment" : false,
                                                "Instance" : true
                                            }
                                        }
                                    }
                                },
                                "IPAddressGroups": [ "_global" ],
                                "RootCredentials" : {
                                    "SecretStore" : {
                                        "Tier" : "app",
                                        "Component" : "directoryadsecretstore",
                                        "Instance" : "",
                                        "Version" :""
                                    }
                                }
                            }
                        },
                        "directoryadsecretstore" : {
                            "secretstore" : {
                                "Instances" : {
                                    "default" : {
                                        "deployment:Unit" : "aws-directoryad-secretstore"
                                    }
                                },
                                "Engine" : "aws:secretsmanager"
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "directoryadbase" : {
                    "OutputSuffix" : "template.json",
                    "Tools" : {
                       "CFNLint" : true
                    },
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "queueHost" : {
                                    "Name" : "directoryXappXdirectoryadbase",
                                    "Type" : "AWS::DirectoryService::MicrosoftAD"
                                },
                                "securityGroup" : {
                                    "Name" : "securityGroupXdirectoryXappXdirectoryadbase",
                                    "Type" : "AWS::EC2::SecurityGroup"
                                },
                                "rootSecret" : {
                                    "Name" : "secretXappXdirectoryadbaseXroot",
                                    "Type" : "AWS::SecretsManager::Secret"
                                }
                            },
                            "Output" : [
                                "directoryXappXdirectoryadbaseXip",
                                "securityGroupXdirectoryXappXdirectoryadbase",
                                "secretXappXdirectoryadbaseXroot"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "directoryadbase" : {
                    "directory" : {
                        "TestCases" : [ "directoryadbase" ]
                    }
                }
            }
        }
    /]

[/#macro]
