[#ftl]

[@addModule
    name="contentnode"
    description="Testing module for the aws handling of contentnodes"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_contentnode  ]

    [#-- ! TODO(roleyfoley): Testing not performed as we can't tests scripts at the moment --]

    [#-- Mobile App --]
    [@loadModule
        settingSets=[
            {
                "Type" : "Settings",
                "Scope" : "Accounts",
                "Namespace" : "mockacct-shared",
                "Settings" : {
                    "Registries": {
                        "contentnode": {
                            "EndPoint": "account-registry-abc123",
                            "Prefix": "contentnode/"
                        }
                    }
                }
            },
            {
                "Type" : "Builds",
                "Scope" : "Products",
                "Namespace" : "mockedup-integration-aws-contentnode-base",
                "Settings" : {
                    "COMMIT" : "123456789#MockCommit#",
                    "FORMATS" : [ "contentnode" ]
                }
            }
        ]
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "contentnodebasecontenthub" : {
                            "contenthub" : {
                                "Instances" : {
                                    "default" : {
                                        "deployment:Unit" : "aws-contentnode-base-contenthub"
                                    }
                                },
                                "Prefix" : "/"
                            }
                        },
                        "contentnodebase" : {
                            "contentnode" : {
                                "Instances" : {
                                    "default" : {
                                        "deployment:Unit" : "aws-contentnode-base"
                                    }
                                },
                                "Links" : {
                                    "contenthub" : {
                                        "Tier" : "app",
                                        "Component" : "contentnodebasecontenthub",
                                        "Instance" : "",
                                        "Version" : ""
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
