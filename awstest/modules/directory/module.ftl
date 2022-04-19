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
                        "directorybase_simple":{
                            "Type": "directory",
                            "deployment:Unit": "aws-directory",
                            "Engine": "Simple",
                            "Size": "Small",
                            "Profiles" : {
                                "Testing" : [ "directorybase_simple" ]
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
                                    "Component" : "directorybase_simple_secretstore",
                                    "Instance" : "",
                                    "Version" :""
                                },
                                "Secret" : {
                                    "Source" : "generated"
                                }
                            }
                        },
                        "directorybase_simple_secretstore" : {
                            "Type": "secretstore",
                            "deployment:Unit" : "aws-directory",
                            "Engine" : "aws:secretsmanager"
                        }
                    }
                }
            },
            "TestCases" : {
                "directorybase_simple" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "directoryHost" : {
                                    "Name" : "directoryXappXdirectorybaseXsimple",
                                    "Type" : "AWS::DirectoryService::SimpleAD"
                                },
                                "rootSecret" : {
                                    "Name" : "secretXappXdirectorybaseXsimpleXAdmin",
                                    "Type" : "AWS::SecretsManager::Secret"
                                }
                            },
                            "Output" : [
                                "directoryXappXdirectorybaseXsimpleXip",
                                "secretXappXdirectorybaseXsimpleXAdmin"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "directorybase_simple" : {
                    "directory" : {
                        "TestCases" : [ "directorybase_simple" ]
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
                        "directorybase_ad":{
                            "Type": "directory",
                            "deployment:Unit": "aws-directory",
                            "Engine": "ActiveDirectory",
                            "Size": "Small",
                            "Profiles" : {
                                "Testing" : [ "directorybase_ad" ]
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
                                    "Component" : "directorybase_ad_secretstore",
                                    "Instance" : "",
                                    "Version" :""
                                },
                                "Secret" : {
                                    "Source" : "generated"
                                }
                            }
                        },
                        "directorybase_ad_secretstore" : {
                            "Type": "secretstore",
                            "deployment:Unit": "aws-directory",
                            "Engine" : "aws:secretsmanager"
                        }
                    }
                }
            },
            "TestCases" : {
                "directorybase_ad" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "directoryHost" : {
                                    "Name" : "directoryXappXdirectorybaseXad",
                                    "Type" : "AWS::DirectoryService::MicrosoftAD"
                                },
                                "rootSecret" : {
                                    "Name" : "secretXappXdirectorybaseXadXAdmin",
                                    "Type" : "AWS::SecretsManager::Secret"
                                }
                            },
                            "Output" : [
                                "directoryXappXdirectorybaseXadXip",
                                "secretXappXdirectorybaseXadXAdmin"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "directorybase_ad" : {
                    "directory" : {
                        "TestCases" : [ "directorybase_ad" ]
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
                        "directorybase_adconnector" : {
                            "Type" : "directory",
                            "deployment:Unit" : "aws-directory",
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
                                    "Component" : "directorybase_adconnector_secretstore",
                                    "SubComponent" : "adconnector_user"
                                }
                            }
                        },
                        "directorybase_adconnector_secretstore" : {
                            "Type" : "secretstore",
                            "deployment:Unit" : "aws-directory",
                            "Engine" : "aws:secretsmanager",
                            "Secrets" : {
                                "adconnector_user" : {}
                            }
                        }
                    }
                }
            }
        }
        stackOutputs=[
            {
                "Account" : "0123456789",
                "Region" : "mock-region-1",
                "DeploymentUnit" : "aws-directory",

                "secretXappXdirectorybaseXadconnectorXsecretstoreXadconnectorXuser": "mockedup-integration-application-directorybase_adconnector_secretstore-adconnector_user"
            }
        ]
    /]

[/#macro]
