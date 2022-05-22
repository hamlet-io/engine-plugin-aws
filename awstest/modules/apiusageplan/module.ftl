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
            "appXapiusageplanbaseXapigw" : {
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
                "Namespace" : "mockedup-integration-app-apiusageplanbase_apigw-apigateway",
                "Settings" : {
                    "COMMIT" : "123456789#MockCommit#",
                    "FORMATS" : ["openapi"]
                }
            },
            {
                "Type" : "Settings",
                "Scope" : "Products",
                "Namespace" : "mockedup-integration-app-apiusageplanbase_apigw-apigateway",
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
                        "apiusageplanbase_usageplan": {
                            "Type": "apiusageplan",
                            "deployment:Unit" : "aws-apiusageplan",
                            "Links": {
                                "apigatewaybase": {
                                    "Tier": "app",
                                    "Component": "apiusageplanbase_apigw"
                                }
                            },
                            "Profiles" : {
                                "Testing" : [ "apiusageplanbase" ]
                            }
                        },
                        "apiusageplanbase_apigw" : {
                            "Type": "apigateway",
                            "deployment:Unit": "aws-apiusageplan",
                            "Image" : {
                                "Source" : "none"
                            },
                            "IPAddressGroups": ["_global"]
                        },
                        "apiusageplanbase_user": {
                            "Type": "user",
                            "deployment:Unit": "aws-apiusageplan",
                            "Links": {
                                "uageplan": {
                                    "Tier": "app",
                                    "Component": "apiusageplanbase_usageplan"
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
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
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
                                    "Name" : "apiUsagePlanXappXapiusageplanbaseXusageplan",
                                    "Type" : "AWS::ApiGateway::UsagePlan"
                                },
                                "User" : {
                                    "Name" : "userXappXapiusageplanbaseXuser",
                                    "Type" : "AWS::IAM::User"
                                },
                                "PlanKey" : {
                                    "Name" : "apiUsagePlanMemberXapiKeyXuserXappXapiusageplanbaseXuserXuageplan",
                                    "Type" : "AWS::ApiGateway::UsagePlanKey"
                                },
                                "ApiKey" : {
                                    "Name" : "apiKeyXuserXappXapiusageplanbaseXuser",
                                    "Type" : "AWS::ApiGateway::ApiKey"
                                }
                            },
                            "Output" : [
                                "apiUsagePlanXappXapiusageplanbaseXusageplan",
                                "apiKeyXuserXappXapiusageplanbaseXuser",
                                "userXappXapiusageplanbaseXuser"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "PlanName" : {
                                    "Path"  : "Resources.apiUsagePlanXappXapiusageplanbaseXusageplan.Properties.UsagePlanName",
                                    "Value" : "mockedup-integration-application-apiusageplanbase_usageplan"
                                },
                                "PlanTagName" : {
                                    "Path"  : "Resources.apiUsagePlanXappXapiusageplanbaseXusageplan.Properties.Tags[0].Value",
                                    "Value" : "mockedup-integration-application-apiusageplanbase_usageplan"
                                },
                                "ApiStageId" : {
                                    "Path"  : "Resources.apiUsagePlanXappXapiusageplanbaseXusageplan.Properties.ApiStages[0].ApiId",
                                    "Value" : "api-abc123def"
                                },
                                "UsagePlanAssignedToKey" : {
                                    "Path"  : "Resources.apiUsagePlanMemberXapiKeyXuserXappXapiusageplanbaseXuserXuageplan.Properties.KeyId",
                                    "Value" : "key-1234def"
                                },
                                "ApiUserName" : {
                                    "Path"  : "Resources.apiKeyXuserXappXapiusageplanbaseXuser.Properties.Tags[0].Value",
                                    "Value" : "mockedup-integration-application-apiusageplanbase_user"
                                }
                            }
                        }
                    }
                }
            }
        }
        stackOutputs=[
            {
                "Account" : "0123456789",
                "Region" : "mock-region-1",
                "DeploymentUnit" : "aws-cdn",
                "apigatewayXappXapiusageplanbaseXapigw": "api-abc123def",
                "apiKeyXuserXappXapiusageplanbaseXuser": "key-1234def",
                "apiKeyXuserXappXapiusageplanbaseXuserXname": "mockedup-integration-application-apiusageplanbase_user",
                "apiUsagePlanXappXapiusageplanbaseXusageplan": "abc123"
            }
        ]
    /]
[/#macro]
