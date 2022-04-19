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
                        "filesharebase_nfs" : {
                            "Type" : "fileshare",
                            "deployment:Unit" : "aws-fileshare",
                            "Engine" : "NFS",
                            "Profiles" : {
                                "Testing" : [ "filesharebase_nfs" ]
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "filesharebase_nfs" : {
                    "OutputSuffix" : "template.json",
                     "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "fileSystem" : {
                                    "Name" : "efsXappXfilesharebaseXnfs",
                                    "Type" : "AWS::EFS::FileSystem"
                                },
                                "securityGroup" : {
                                    "Name" : "securityGroupXefsXappXfilesharebaseXnfs",
                                    "Type" : "AWS::EC2::SecurityGroup"
                                },
                                "mountTargetA" : {
                                    "Name" : "efsMountTargetXefsXappXfilesharebaseXnfsXa",
                                    "Type" : "AWS::EFS::MountTarget"
                                },
                                "mountTargetB" : {
                                    "Name" : "efsMountTargetXefsXappXfilesharebaseXnfsXb",
                                    "Type" : "AWS::EFS::MountTarget"
                                }
                            },
                            "Output" : [
                                "efsXappXfilesharebaseXnfs",
                                "securityGroupXefsXappXfilesharebaseXnfs"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "filesharebase_nfs" : {
                    "fileshare" : {
                        "TestCases" : [ "filesharebase_nfs" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
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
                        "filesharebase_smb" : {
                            "Type" : "fileshare",
                            "deployment:Unit" : "aws-fileshare",
                            "Engine" : "SMB",
                            "Size" : 100,
                            "MaintenanceWindow" : {
                                "DayOfTheWeek" : "Sunday",
                                "TimeOfDay" : "00:00",
                                "TimeZone" : "UTC"
                            },
                            "Profiles" : {
                                "Testing" : [ "filesharebase_smb" ]
                            },
                            "Links" : {
                                "directory" : {
                                    "Tier" : "app",
                                    "Component" : "filesharebase_smb_directory"
                                }
                            }
                        },
                        "filesharebase_smb_directory": {
                            "Type" : "directory",
                            "deployment:Unit": "aws-fileshare",
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
                                    "Component" : "filesharebase_smb_secretstore"
                                },
                                "Secret" : {
                                    "Source" : "generated"
                                }
                            }
                        },
                        "filesharebase_smb_secretstore" : {
                            "Type" : "secretstore",
                            "deployment:Unit" : "aws-fileshare",
                            "Engine" : "aws:secretsmanager"
                        }
                    }
                }
            },
            "TestCases" : {
                "filesharebase_smb" : {
                    "OutputSuffix" : "template.json",
                    "Tools" : {
                       "cfn-lint" : {}
                    },
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "fileSystem" : {
                                    "Name" : "fsxfilesystemXappXfilesharebaseXsmb",
                                    "Type" : "AWS::FSx::FileSystem"
                                },
                                "securityGroup" : {
                                    "Name" : "securityGroupXfsxfilesystemXappXfilesharebaseXsmb",
                                    "Type" : "AWS::EC2::SecurityGroup"
                                }
                            },
                            "Output" : [
                                "fsxfilesystemXappXfilesharebaseXsmbXdns",
                                "fsxfilesystemXappXfilesharebaseXsmb"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "filesharebase_smb" : {
                    "fileshare" : {
                        "TestCases" : [ "filesharebase_smb" ]
                    }
                }
            }
        }
        stackOutputs=[
            {
                "Account" : "0123456789",
                "Region" : "mock-region-1",
                "DeploymentUnit" : "aws-fileshare",
                "directoryXappXfilesharebaseXsmbXdirectory": "d-1234567a"
            }
        ]
    /]

[/#macro]
