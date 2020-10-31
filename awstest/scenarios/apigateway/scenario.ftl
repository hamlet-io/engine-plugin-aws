[#ftl]

[@addScenario
    name="apigateway"
    description="Testing scenario for the aws apigateway component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_scenario_apigateway ]

    [#-- Base apigateway setup - No solution parameters --]
    [@addDefinition
        definition={
            "appXapigatewaybase" : {
                "swagger": "2.0",
                "info": {
                    "version": "v1.0.0",
                    "title": "Proxy",
                    "description": "Pass all requests through to the implementation."
                },
                "paths": {
                    "/{proxy+}": {
                        "x-amazon-apigateway-any-method": {
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
    /]

    [@loadScenario
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
                "Namespace" : "mockedup-integration-aws-apigateway-base",
                "Settings" : {
                    "COMMIT" : "123456789#MockCommit#",
                    "FORMATS" : ["openapi"]
                }
            },
            {
                "Type" : "Settings",
                "Scope" : "Products",
                "Namespace" : "mockedup-integration-aws-apigateway-base",
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
                                        "DeploymentUnits" : ["aws-apigateway-base"]
                                    }
                                },
                                "IPAddressGroups" : [ "_global" ],
                                "Profiles" : {
                                    "Testing" : [ "apigatewaybase" ]
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "apigatewaybase" : {
                    "apigateway" : {
                        "TestCases" : [ "apigatewaybase" ]
                    }
                }
            },
            "TestCases" : {
                "apigatewaybase" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "RestApi" : {
                                    "Name" : "apiXappXapigatewaybase",
                                    "Type" : "AWS::ApiGateway::RestApi"
                                },
                                "Deployment" : {
                                    "Name" : "apiDeployXappXapigatewaybaseXrunId098",
                                    "Type" : "AWS::ApiGateway::Deployment"
                                }
                            },
                            "Output" : [
                                "apiXappXapigatewaybase",
                                "apiXappXapigatewaybaseXroot",
                                "apiXappXapigatewaybaseXregion"
                            ]
                        }
                    }
                }
            }
        }
    /]
[/#macro]
