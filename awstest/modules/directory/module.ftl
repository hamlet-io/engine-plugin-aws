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
                                    },
                                    "Secret" : {
                                        "Source" : "generated"
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
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "directoryHost" : {
                                    "Name" : "directoryXappXdirectorysimplebase",
                                    "Type" : "AWS::DirectoryService::SimpleAD"
                                },
                                "rootSecret" : {
                                    "Name" : "secretXappXdirectorysimplebaseXAdmin",
                                    "Type" : "AWS::SecretsManager::Secret"
                                }
                            },
                            "Output" : [
                                "directoryXappXdirectorysimplebaseXip",
                                "secretXappXdirectorysimplebaseXAdmin"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "directorysimplebase" : {
                    "directory" : {
                        "TestCases" : [ "directorysimplebase" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
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
                                    },
                                    "Secret" : {
                                        "Source" : "generated"
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
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "directoryHost" : {
                                    "Name" : "directoryXappXdirectoryadbase",
                                    "Type" : "AWS::DirectoryService::MicrosoftAD"
                                },
                                "rootSecret" : {
                                    "Name" : "secretXappXdirectoryadbaseXAdmin",
                                    "Type" : "AWS::SecretsManager::Secret"
                                }
                            },
                            "Output" : [
                                "directoryXappXdirectoryadbaseXip",
                                "secretXappXdirectoryadbaseXAdmin"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "directoryadbase" : {
                    "directory" : {
                        "TestCases" : [ "directoryadbase" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]

    [#-- AD Connector --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "adconnectorbase" : {
                            "Type" : "directory",
                            "deployment:Unit" : "aws-adconnector-base",
                            "Engine" : "aws:ADConnector",
                            "Size" : "Small",
                            "aws:engine:ADConnector" : {
                                "ADIPAddresses" : [
                                    "10.1.1.1",
                                    "10.1.1.2"
                                ]
                            },
                            "RootCredentials" : {
                                "Source" : "user",
                                "Link" : {
                                    "Tier" : "app",
                                    "Component" : "adconnectorbasesecret",
                                    "SubComponent" : "adconnectorbaseuser"
                                }
                            }
                        },
                        "adconnectorbasesecret" : {
                            "Type" : "secretstore",
                            "deployment:Unit" : "aws-adconnector-base-secret",
                            "Engine" : "aws:secretsmanager",
                            "Secrets" : {
                                "adconnectorbaseuser" : {}
                            }
                        }
                    }
                }
            }
        }
    /]

[/#macro]
