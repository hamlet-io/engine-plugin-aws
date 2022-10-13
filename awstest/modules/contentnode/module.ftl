[#ftl]

[@addModule
    name="contentnode"
    description="Testing module for the aws handling of contentnodes"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_contentnode  ]

    [#-- ! TODO(roleyfoley): Testing not performed as we can't tests scripts at the moment --]

    [#-- Base --]
    [@loadModule
        settingSets=[
            {
                "Type" : "Builds",
                "Scope" : "Products",
                "Namespace" : "mockedup-integration-app-contentnodebase",
                "Settings" : {
                    "COMMIT" : "123456789#MockCommit#"
                }
            }
        ]
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "contentnodebase" : {
                            "Type": "contentnode",
                            "deployment:Unit": "aws-contentnode",
                            "Links" : {
                                "contenthub" : {
                                    "Tier" : "app",
                                    "Component" : "contentnodebase_contenthub",
                                    "Instance" : "",
                                    "Version" : ""
                                }
                            }
                        },
                        "contentnodebase_contenthub" : {
                            "Type" : "contenthub",
                            "deployment:Unit": "aws-contentnode",
                            "Prefix" : "/"
                        }
                    }
                }
            }
        }
    /]
[/#macro]
