[#ftl]

[#-- Intial seeding of settings data based on input data --]
[#macro awstest_input_shared_blueprint_seed ]
    [@addBlueprint
        blueprint={
            "Solution" : {
                "Modules" : {
                    "apigateway" : {
                        "Provider" : "awstest",
                        "Name" : "apigateway"
                    },
                    "db" : {
                        "Provider" : "awstest",
                        "Name" : "db"
                    },
                    "filetransfer" : {
                        "Provider" : "awstest",
                        "Name" : "filetransfer"
                    },
                    "lb" : {
                        "Provider" : "awstest",
                        "Name" : "lb"
                    },
                    "s3" : {
                        "Provider" : "awstest",
                        "Name" : "s3"
                    }
                }
            },
            "DeploymentGroups" : {
                "segment" : {
                    "ResourceSets" : {
                        "iam" : {
                            "Enabled" : false
                        },
                        "lg" : {
                            "Enabled" : false
                        },
                        "eip" : {
                            "Enabled" : false
                        },
                        "s3" : {
                            "Enabled" : false
                        },
                        "cmk" : {
                            "Enabled" : false
                        }
                    }
                },
                "solution" : {
                    "ResourceSets" : {
                        "eip" : {
                            "Enabled" : false
                        },
                        "iam" : {
                            "Enabled" : false
                        },
                        "lg" : {
                            "Enabled" : false
                        }
                    }
                },
                "application" : {
                    "ResourceSets" : {
                        "iam" : {
                            "Enabled" : false
                        },
                        "lg" : {
                            "Enabled" : false
                        }
                    }
                }
            }
        }
    /]
[/#macro]
