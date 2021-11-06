[#ftl]

[@addModule
    name="fileshare"
    description="Testing module for the aws fileshare component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_fileshare  ]

    [#-- NFS File Share --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "filesharenfsbase" : {
                            "Type" : "fileshare",
                            "deployment:Unit" : "aws-fileshare-nfs-base",
                            "Engine" : "NFS",
                            "Profiles" : {
                                "Testing" : [ "filesharenfsbase" ]
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "filesharenfsbase" : {
                    "OutputSuffix" : "template.json",
                    "Tools" : {
                       "cfn-lint" : {}
                    },
                     "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "fileSystem" : {
                                    "Name" : "efsXappXfilesharenfsbase",
                                    "Type" : "AWS::EFS::FileSystem"
                                },
                                "securityGroup" : {
                                    "Name" : "securityGroupXefsXappXfilesharenfsbase",
                                    "Type" : "AWS::EC2::SecurityGroup"
                                },
                                "mountTargetA" : {
                                    "Name" : "efsMountTargetXefsXappXfilesharenfsbaseXa",
                                    "Type" : "AWS::EFS::MountTarget"
                                },
                                "mountTargetB" : {
                                    "Name" : "efsMountTargetXefsXappXfilesharenfsbaseXb",
                                    "Type" : "AWS::EFS::MountTarget"
                                }
                            },
                            "Output" : [
                                "efsXappXfilesharenfsbase",
                                "securityGroupXefsXappXfilesharenfsbase"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "filesharenfsbase" : {
                    "fileshare" : {
                        "TestCases" : [ "filesharenfsbase" ]
                    }
                }
            }
        }
    /]

    [#-- SMB File Share --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "filesharesmbbase" : {
                            "Type" : "fileshare",
                            "deployment:Unit" : "aws-fileshare-smb-base",
                            "Engine" : "SMB",
                            "Size" : 100,
                            "MaintenanceWindow" : {
                                "DayOfTheWeek" : "Sunday",
                                "TimeOfDay" : "00:00",
                                "TimeZone" : "UTC"
                            },
                            "Profiles" : {
                                "Testing" : [ "filesharesmbbase" ]
                            },
                            "Links" : {
                                "directory" : {
                                    "Tier" : "app",
                                    "Component" : "filesharesmbbasedirectory"
                                }
                            }
                        },
                        "filesharesmbbasedirectory": {
                            "Type" : "directory",
                            "deployment:Unit": "aws-fileshare-smb-base-directory",
                            "Engine": "ActiveDirectory",
                            "Size": "Small",
                            "Hostname" : {
                                "IncludeInHost" : {
                                    "Component" : false,
                                    "Environment" : false
                                }
                            },
                            "RootCredentials" : {
                                "SecretStore" : {
                                    "Tier" : "app",
                                    "Component" : "filesharesmbbasesecretstore"
                                },
                                "Secret" : {
                                    "Source" : "generated"
                                }
                            }
                        },
                        "filesharesmbbasesecretstore" : {
                            "Type" : "secretstore",
                            "deployment:Unit" : "aws-fileshare-smb-base-secretstore",
                            "Engine" : "aws:secretsmanager"
                        }
                    }
                }
            },
            "TestCases" : {
                "filesharesmbbase" : {
                    "OutputSuffix" : "template.json",
                    "Tools" : {
                       "cfn-lint" : {}
                    },
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "fileSystem" : {
                                    "Name" : "fsxfilesystemXappXfilesharesmbbase",
                                    "Type" : "AWS::FSx::FileSystem"
                                },
                                "securityGroup" : {
                                    "Name" : "securityGroupXfsxfilesystemXappXfilesharesmbbase",
                                    "Type" : "AWS::EC2::SecurityGroup"
                                }
                            },
                            "Output" : [
                                "fsxfilesystemXappXfilesharesmbbaseXdns",
                                "fsxfilesystemXappXfilesharesmbbase"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "filesharesmbbase" : {
                    "fileshare" : {
                        "TestCases" : [ "filesharesmbbase" ]
                    }
                }
            }
        }
    /]

[/#macro]
