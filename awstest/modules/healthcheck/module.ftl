[#ftl]

[@addModule
    name="healthcheck"
    description="Testing module for the aws healthcheck component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_healthcheck  ]

    [@loadModule
        blueprint={
            "Tiers" : {
                "elb" : {
                    "Components" : {
                        "healthchecklb" : {
                            "Type" : "lb",
                            "deployment:Unit" : "aws-healthcheck-lb",
                            "Engine" : "application",
                            "PortMappings" : {
                                "https" : {},
                                "http" : {}
                            }
                        }
                    }
                },
                "app" : {
                    "Components" : {
                        [#-- simple health checks must be in us-east-1 --]
                        [#-- we can't control region through modules at the moment so can't include in testing --]
                        [#-- TODO(roleyfoley): enable when placements fully control region --]
                        "healthchecksimplebase" : {
                            "Type" : "healthcheck",
                            "Enabled" : false,
                            "deployment:Unit" : "aws-healthcheck-simple-base",
                            "Engine" : "Simple",
                            "Engine:Simple" : {
                                "Destination": {
                                    "Link" : {
                                        "Tier" : "elb",
                                        "Component" : "healthchecklb",
                                        "PortMapping" : "https",
                                        "Instance" : "",
                                        "Version" : ""
                                    }
                                },
                                "Port" : "https"
                            },
                            "Profiles" : {
                                "Testing" : [ "healthchecksimplebase" ],
                                "Placement" : "healtchecksimple"
                            }
                        },
                        "healthcheckcomplexbase" : {
                            "Type" : "healthcheck",
                            "deployment:Unit" : "aws-healthcheck-complex-base",
                            "Engine" : "Complex",
                            "Engine:Complex" : {
                                "Image": {
                                    "Source" : "none"
                                },
                                "Handler" : "handler",
                                "RunTime" : "syn-python-selenium-1.0"
                            },
                            "Extenions" : [ "_healthcheckcomplexbase" ],
                            "Links" : {
                                "lb": {
                                    "Tier" : "elb",
                                    "Component" : "healthchecklb",
                                    "PortMapping" : "https",
                                    "Instance" : "",
                                    "Version" : ""
                                }
                            },
                            "Profiles" : {
                                "Testing" : [ "healthcheckcomplexbase" ]
                            }
                        }
                    }
                }
            },
            "PlacementProfiles": {
                "healtchecksimple": {
                    "default": {
                        "Provider": "aws",
                        "Region": "us-east-1",
                        "DeploymentFramework": "cf"
                    }
                }
            },
            "TestCases" : {
                "healthchecksimplebase" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "healthCheck" : {
                                    "Name" : "route53HealthCheckXappXhealthchecksimplebase",
                                    "Type" : "AWS::Route53::HealthCheck"
                                }
                            },
                            "Output" : [
                                "route53HealthCheckXappXhealthchecksimplebase"
                            ]
                        }
                    }
                },
                "healthcheckcomplexbase" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "canary" : {
                                    "Name" : "canaryXappXhealthcheckcomplexbase",
                                    "Type" : "AWS::Synthetics::Canary"
                                }
                            },
                            "Output" : [
                                "canaryXappXhealthcheckcomplexbase"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "CanaryName" : {
                                    "Path"  : "Resources.canaryXappXhealthcheckcomplexbase.Properties.Name",
                                    "Value" : "healthcheckcomplexbas"
                                },
                                "ArtifactS3Location" : {
                                    "Path"  : "Resources.canaryXappXhealthcheckcomplexbase.Properties.ArtifactS3Location",
                                    "Value" : "s3://##MockOutputXs3XsegmentXapplicationX##/appdata/mockedup/integration/application/healthcheckcomplexbase"
                                },
                                "EnvVars" : {
                                    "Path" : "Resources.canaryXappXhealthcheckcomplexbase.Properties.RunConfig.EnvironmentVariables.LB_FQDN",
                                    "Value" : "healthchecklb-integration.mock.local"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "healthchecksimplebase" : {
                    "healthcheck" : {
                        "TestCases" : [ "healthchecksimplebase" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                },
                "healthcheckcomplexbase" : {
                    "healthcheck" : {
                        "TestCases" : [ "healthcheckcomplexbase" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]
[/#macro]
