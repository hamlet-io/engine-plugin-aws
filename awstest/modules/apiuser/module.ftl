[#ftl]

[@addModule
    name="apiuser"
    description="Testing module for the aws apiuser component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_apiuser ]

    [#-- Base apiuser setup - No solution parameters --]
    [@loadModule
        definitions={
            "appXapiuserbase" : {
                "swagger": "2.0",
                "info": {
                    "version": "v1.0.0",
                    "title": "Proxy",
                    "description": "Pass all requests through to the implementation."
                },
                "paths": {
                    "/{proxy+}": {
                        "x-amazon-apiuser-any-method": {
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
                "Namespace" : "mockedup-integration-aws-apiuser-base",
                "Settings" : {
                    "COMMIT" : "123456789#MockCommit#",
                    "FORMATS" : ["openapi"]
                }
            },
            {
                "Type" : "Settings",
                "Scope" : "Products",
                "Namespace" : "mockedup-integration-aws-apiuser-base",
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
                        "gw" : {
                            "apigateway" : {
                                "Instances" : {
                                    "default" : {
                                        "DeploymentUnits" : ["aws-apiuser-base-gw"]
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
                                            "aws-apiuser-base-up"
                                        ],
                                        "Links": {
                                            "apigatewaybase": {
                                                "Tier": "app",
                                                "Component": "apigatewaybase"
                                            }
                                        }
                                    }
                                }
                            }
                        },
                        "apiuserbase": {
                            "user": {
                                "Instances": {
                                    "default": {
                                        "DeploymentUnits": [
                                            "aws-apiuser"
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
                                },
                                "Profiles" : {
                                    "Testing" : [ "apiuserbase" ]
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "apiuserbase" : {
                    "user" : {
                        "TestCases" : [ "apiuserbase" ]
                    }
                }
            },
            "TestCases" : {
                "apiuserbase" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "User" : {
                                    "Name" : "userXappXapiuserbase",
                                    "Type" : "AWS::IAM::User"
                                },
                                "PlanKey" : {
                                    "Name" : "apiUsagePlanMemberXapiKeyXuserXappXapiuserbaseXplan",
                                    "Type" : "AWS::ApiGateway::UsagePlanKey"
                                },
                                "ApiKey" : {
                                    "Name" : "apiKeyXuserXappXapiuserbase",
                                    "Type" : "AWS::ApiGateway::ApiKey"
                                }
                            },
                            "Output" : [
                                "userXappXapiuserbase",
                                "userXappXapiuserbaseXarn",
                                "apiKeyXuserXappXapiuserbase"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "ApiKey" : {
                                    "Path"  : "Resources.apiUsagePlanMemberXapiKeyXuserXappXapiuserbaseXplan.Properties.KeyId",
                                    "Value" : "##MockOutputXapiKeyXuserXappXapiuserbaseX##"
                                },
                                "ApiUserName" : {
                                    "Path"  : "Resources.apiKeyXuserXappXapiuserbase.Properties.Tags[8].Value",
                                    "Value" : "mockedup-integration-application-apiuserbase"
                                },
                                "UserTags": {
                                    "Path"  : "Resources.userXappXapiuserbase.Properties.Tags[10].Value",
                                    "Value" : "mockedup-int-app-apiuserbase"
                                }
                            }
                        }
                    }
                }
            }
        }
    /]
[/#macro]
