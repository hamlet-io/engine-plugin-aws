[#ftl]

[#-- Get stack output --]
[#macro awstest_scenario_s3 ]

    [#-- Base database setup --]
    [@addScenario
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "s3base" : {
                            "s3" : {
                                "Instances" : {
                                    "default" : {
                                        "DeploymentUnits" : ["aws-s3-base"]
                                    }
                                },
                                "Profiles" : {
                                    "Testing" : [ "s3base" ]
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "s3base" : {
                    "s3" : {
                        "TestCases" : [ "s3base" ]
                    }
                }
            },
            "TestCases" : {
                "s3base" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "s3Bucket" : {
                                    "Name" : "s3XappXs3base",
                                    "Type" : "AWS::S3::Bucket"
                                }
                            },
                            "Output" : [
                                "s3XappXs3base",
                                "s3XappXs3baseXname",
                                "s3XappXs3baseXarn",
                                "s3XappXs3baseXregion"
                            ]
                        }
                    }
                }
            }
        }
    /]
[/#macro]
