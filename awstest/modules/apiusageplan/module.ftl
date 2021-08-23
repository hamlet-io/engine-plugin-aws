[#ftl]

[@addModule
    name="apiusageplan"
    description="Testing module for the aws apiusageplan component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_apiusageplan ]

    [#-- Base apiusageplan setup - No solution parameters --]
    [@loadModule
        definitions={
            "appXapiusageplanbase" : {
                "swagger": "2.0",
                "info": {
                    "version": "v1.0.0",
                    "title": "Proxy",
                    "description": "Pass all requests through to the implementation."
                },
                "paths": {
                    "/{proxy+}": {
                        "x-amazon-apiusageplan-any-method": {
                        }
                    }
                },
                "definitions": {
                    "Empty": {
                        "type": "object",
                        "title": "Empty Schema"
                    }
                }
            }
        }
        settingSets=[
            {
                "Type" : "Settings",
                "Scope" : "Accounts",
                "Namespace" : "mockacct-shared",
                "Settings" : {
                    "Registries": {
                        "openapi": {
                            "EndPoint": "account-registry-abc123",
                            "Prefix": "openapi/"
                        }
                    }
                }
            },
            {
                "Type" : "Builds",
                "Scope" : "Products",
                "Namespace" : "mockedup-integration-aws-apiusageplan-base",
                "Settings" : {
                    "COMMIT" : "123456789#MockCommit#",
                    "FORMATS" : ["openapi"]
                }
            },
            {
                "Type" : "Settings",
                "Scope" : "Products",
                "Namespace" : "mockedup-integration-aws-apiusageplan-base",
                "Settings" : {
                    "apigw": {
                        "Internal": true,
                        "Value": {
                            "Type": "lambda",
                            "Proxy": false,
                            "BinaryTypes": ["*/*"],
                            "ContentHandling": "CONVERT_TO_TEXT",
                            "Variable": "LAMBDA_API_LAMBDA"
                        }
                    }
                }
            }
        ]
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "apigatewaybase" : {
                            "apigateway" : {
                                "Instances" : {
                                    "default" : {
                                        "DeploymentUnits" : ["aws-apiusageplan-base-gw"]
                                    }
                                },
                                "Image" : {
                                    "Source" : "none"
                                },
                                "IPAddressGroups" : [ "_global" ]
                            }
                        },
                        "plan": {
                            "APIUsagePlan": {
                                "Instances": {
                                    "default": {
                                        "DeploymentUnits": [
                                            "aws-apiusageplan-base"
                                        ],
                                        "Links": {
                                            "apigatewaybase": {
                                                "Tier": "app",
                                                "Component": "apigatewaybase"
                                            }
                                        }
                                    }
                                },
                                "Profiles" : {
                                    "Testing" : [ "apiusageplanbase" ]
                                }
                            }
                        },
                        "user": {
                            "user": {
                                "Instances": {
                                    "default": {
                                        "DeploymentUnits": [
                                            "aws-apiusageplan-base-usr"
                                        ]
                                    }
                                },
                                "GenerateCredentials": {
                                    "Formats": [
                                        "system"
                                    ]
                                },
                                "Links": {
                                    "plan": {
                                        "Tier": "app",
                                        "Component": "plan"
                                    }
                                },
                                "Permissions": {
                                    "Decrypt": false,
                                    "AsFile": false,
                                    "AppData": false,
                                    "AppPublic": false
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "apiusageplanbase" : {
                    "apiusageplan" : {
                        "TestCases" : [ "apiusageplanbase" ]
                    }
                }
            },
            "TestCases" : {
                "apiusageplanbase" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "Plan" : {
                                    "Name" : "apiUsagePlanXappXplan",
                                    "Type" : "AWS::ApiGateway::UsagePlan"
                                }
                            },
                            "Output" : [
                                "apiUsagePlanXappXplan"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "PlanName" : {
                                    "Path"  : "Resources.apiUsagePlanXappXplan.Properties.UsagePlanName",
                                    "Value" : "mockedup-integration-application-plan"
                                },
                                "PlanTagName" : {
                                    "Path"  : "Resources.apiUsagePlanXappXplan.Properties.Tags[8].Value",
                                    "Value" : "mockedup-integration-application-plan"
                                },
                                "ApiStageId" : {
                                    "Path"  : "Resources.apiUsagePlanXappXplan.Properties.ApiStages[0].ApiId",
                                    "Value" : "##MockOutputXapiXappXapigatewaybaseX##"
                                }
                            }
                        }
                    }
                }
            }
        }
    /]
[/#macro]
