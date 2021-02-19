[#ftl]

[@addModule
    name="no_master_resourcesets"
    description="Disables the resource set configuration provided by the masterdata"
    provider=AWS_PROVIDER
    properties=[]
/]

[#macro aws_module_no_master_resourcesets ]
    [@loadModule
        blueprint={
            "DeploymentGroups": {
                "segment": {
                    "ResourceSets": {
                        "iam": {
                            "Enabled": false
                        },
                        "lg": {
                            "Enabled": false
                        },
                        "eip": {
                            "Enabled": false
                        },
                        "s3": {
                            "Enabled": false
                        },
                        "cmk": {
                            "Enabled": false
                        }
                    }
                },
                "solution": {
                    "ResourceSets": {
                        "eip": {
                            "Enabled": false
                        },
                        "iam": {
                            "Enabled": false
                        },
                        "lg": {
                            "Enabled": false
                        }
                    }
                },
                "application": {
                    "ResourceSets": {
                        "iam": {
                            "Enabled": false
                        },
                        "lg": {
                            "Enabled": false
                        }
                    }
                }
            }
        }
    /]
[/#macro]
