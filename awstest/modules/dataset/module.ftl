[#ftl]

[@addModule
    name="dataset"
    description="Testing module for the aws management of datasets"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_dataset ]

    [#-- Mobile App --]
    [#-- TODO(roleyfoley): testing only works on JSON and no json outputs are generated for datasets --]
    [@loadModule
        settingSets=[
            {
                "Type" : "Settings",
                "Scope" : "Accounts",
                "Namespace" : "mockacct-shared",
                "Settings" : {
                    "Registries": {
                        "dataset": {
                            "EndPoint": "account-registry-abc123",
                            "Prefix": "dataset/"
                        }
                    }
                }
            },
            {
                "Type" : "Builds",
                "Scope" : "Products",
                "Namespace" : "mockedup-integration-aws-dataset-base",
                "Settings" : {
                    "COMMIT" : "123456789#MockCommit#",
                    "FORMATS" : ["dataset"]
                }
            }
        ]
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "datasetbases3" : {
                            "dataset" : {
                                "Instances" : {
                                    "default" : {
                                        "DeploymentUnits" : ["aws-dataset-base-s3"]
                                    }
                                },
                                "Engine" : "s3",
                                "BuildEnvironment" : [ "integration" ]
                            }
                        }
                    }
                }
            }
        }
    /]
[/#macro]
