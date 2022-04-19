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
                        "healthcheck_lb" : {
                            "Type" : "lb",
                            "deployment:Unit" : "aws-healthcheck",
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
                        "healthcheckbase_simple" : {
                            "Type" : "healthcheck",
                            "Enabled" : false,
                            "deployment:Unit" : "aws-healthcheck",
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
                        "healthcheckbase_complex" : {
                            "Type" : "healthcheck",
                            "deployment:Unit" : "aws-healthcheck",
                            "Engine" : "Complex",
                            "Engine:Complex" : {
                                "Image": {
                                    "Source" : "none"
                                },
                                "Handler" : "handler",
                                "RunTime" : "syn-python-selenium-1.0"
                            },
                            "Extensions" : [ "_healthcheckbasecomplex" ],
                            "Links" : {
                                "lb": {
                                    "Tier" : "elb",
                                    "Component" : "healthcheck_lb",
                                    "PortMapping" : "https",
                                    "Instance" : "",
                                    "Version" : ""
                                }
                            },
                            "Profiles" : {
                                "Testing" : [ "healthcheckbase_complex" ]
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
                "healthcheckbase_simple" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "healthCheck" : {
                                    "Name" : "route53HealthCheckXappXhealthcheckbaseXsimple",
                                    "Type" : "AWS::Route53::HealthCheck"
                                }
                            },
                            "Output" : [
                                "route53HealthCheckXappXhealthcheckbaseXsimple"
                            ]
                        }
                    }
                },
                "healthcheckbase_complex" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "canary" : {
                                    "Name" : "canaryXappXhealthcheckbaseXcomplex",
                                    "Type" : "AWS::Synthetics::Canary"
                                }
                            },
                            "Output" : [
                                "canaryXappXhealthcheckbaseXcomplex"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "CanaryName" : {
                                    "Path"  : "Resources.canaryXappXhealthcheckbaseXcomplex.Properties.Name",
                                    "Value" : "56813_mplex"
                                },
                                "ArtifactS3Location" : {
                                    "Path"  : "Resources.canaryXappXhealthcheckbaseXcomplex.Properties.ArtifactS3Location",
                                    "Value" : "s3://segment-baseline-appdata/appdata/mockedup/integration/application/healthcheckbase_complex"
                                },
                                "EnvVars" : {
                                    "Path" : "Resources.canaryXappXhealthcheckbaseXcomplex.Properties.RunConfig.EnvironmentVariables.LB_FQDN",
                                    "Value" : "healthcheck_lb-integration.mock.local"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "healthcheckbase_simple" : {
                    "healthcheck" : {
                        "TestCases" : [ "healthcheckbase_simple" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                },
                "healthcheckbase_complex" : {
                    "healthcheck" : {
                        "TestCases" : [ "healthcheckbase_complex" ]
                    }
                }
            }
        }
    /]
[/#macro]
