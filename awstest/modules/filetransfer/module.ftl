[#ftl]

[@addModule
    name="filetransfer"
    description="Testing module for the aws filetransfer component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_filetransfer  ]

    [#-- Base SFTP File Transfer Server --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "filetransferbase" : {
                            "Type": "filetransfer",
                            "deployment:Unit": "aws-filetransfer",
                            "Protocols" : [ "sftp" ],
                            "Profiles" : {
                                "Testing" : [ "filetransferbase" ]
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "filetransferbase" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "transferServer" : {
                                    "Name" : "transferServerXappXfiletransferbase",
                                    "Type" : "AWS::Transfer::Server"
                                },
                                "securityGroup" : {
                                    "Name" : "securityGroupXtransferServerXappXfiletransferbase",
                                    "Type" : "AWS::EC2::SecurityGroup"
                                }
                            },
                            "Output" : [
                                "transferServerXappXfiletransferbase",
                                "transferServerXappXfiletransferbaseXarn",
                                "transferServerXappXfiletransferbaseXname"
                            ]
                        }
                    }
                }
            },
            "TestProfiles" : {
                "filetransferbase" : {
                    "filetransfer" : {
                        "TestCases" : [ "filetransferbase" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]
[/#macro]
