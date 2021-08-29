[#ftl]

[@addModule
    name="apigateway"
    description="Testing module for the aws apigateway component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_apigateway ]

    [#-- Base apigateway setup - No solution parameters --]
    [@loadModule
        definitions={
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
                                "Certificate": {},
                                "Image" : {
                                    "Source" : "none"
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
                        },
                        "JSON" : {
                            "Match" : {
                                "DeployTagName" : {
                                    "Path"  : "Resources.apiDeployXappXapigatewaybaseXrunId098.Properties.Tags[10].Value",
                                    "Value" : "mockedup-integration-application-apigatewaybase"
                                },
                                "RestAPITagName" : {
                                    "Path"  : "Resources.apiXappXapigatewaybase.Properties.Tags[10].Value",
                                    "Value" : "mockedup-integration-application-apigatewaybase"
                                },
                                "StageTagName" : {
                                    "Path"  : "Resources.apiStageXappXapigatewaybase.Properties.Tags[10].Value",
                                    "Value" : "application-apigatewaybase"
                                }
                            }
                        }
                    }
                }
            }
        }
    /]

    [#-- Domain apigateway setup --]
    [@loadModule
        definitions={
            "appXapigatewaydomain" : {
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
                "Namespace" : "mockedup-integration-aws-apigateway-domain",
                "Settings" : {
                    "COMMIT" : "123456789#MockCommit#",
                    "FORMATS" : ["openapi"]
                }
            },
            {
                "Type" : "Settings",
                "Scope" : "Products",
                "Namespace" : "mockedup-integration-aws-apigateway-domain",
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
                        "apigatewaydomain" : {
                            "apigateway" : {
                                "Instances" : {
                                    "default" : {
                                        "DeploymentUnits" : ["aws-apigateway-domain"]
                                    }
                                },
                                "Certificate": {
                                    "IncludeInHost" : {
                                        "Product" : false,
                                        "Environment" : false,
                                        "Tier" : false,
                                        "Component" : true,
                                        "Instance" : true,
                                        "Version" : false,
                                        "Host" : false
                                    }
                                },
                                "Mapping" : {
                                    "IncludeStage" : true
                                },
                                "Image" : {
                                    "Source" : "none"
                                },
                                "IPAddressGroups" : [ "_global" ],
                                "Profiles" : {
                                    "Testing" : [ "apigatewaydomain" ]
                                }
                            }
                        }
                    }
                }
            },
            "SecurityProfiles": {
                "default": {
                    "apigatewaydomain": {
                        "GatewayHTTPSProfile": "TLS_1_2"
                    }
                }
            },
            "TestProfiles" : {
                "apigatewaydomain" : {
                    "apigateway" : {
                        "TestCases" : [ "apigatewaydomain" ]
                    }
                }
            },
            "TestCases" : {
                "apigatewaydomain" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "RestApi" : {
                                    "Name" : "apiXappXapigatewaydomain",
                                    "Type" : "AWS::ApiGateway::RestApi"
                                },
                                "Domain" : {
                                    "Name" : "apiDomainXapigatewaydomainXmockXlocal",
                                    "Type" : "AWS::ApiGateway::DomainName"
                                }
                            }
                        },
                        "JSON" : {
                            "Match" : {
                                "TagName" : {
                                    "Path"  : "Resources.apiDomainXapigatewaydomainXmockXlocal.Properties.Tags[10].Value",
                                    "Value" : "apigatewaydomain.mock.local"
                                },
                                "DomainName" : {
                                    "Path"  : "Resources.apiDomainXapigatewaydomainXmockXlocal.Properties.DomainName",
                                    "Value" : "apigatewaydomain.mock.local"
                                }
                            }
                        }
                    }
                }
            }
        }
    /]

    [#-- CF distro apigateway setup - No solution parameters --]
    [@loadModule
        definitions={
            "appXapigatewaycfdistro" : {
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
                "Namespace" : "mockedup-integration-aws-apigateway-cfdistro",
                "Settings" : {
                    "COMMIT" : "123456789#MockCommit#",
                    "FORMATS" : ["openapi"]
                }
            },
            {
                "Type" : "Settings",
                "Scope" : "Products",
                "Namespace" : "mockedup-integration-aws-apigateway-cfdistro",
                "Settings" : {
                    "API_ACCESSKEY": "1234567890#MockAPIKey",
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
                        "apigatewaycfdistro" : {
                            "apigateway" : {
                                "Instances" : {
                                    "default" : {
                                        "DeploymentUnits" : ["aws-apigateway-cfdistro"]
                                    }
                                },
                                "Certificate": {},
                                "CloudFront": {},
                                "Image" : {
                                    "Source" : "none"
                                },
                                "IPAddressGroups" : [ "_global" ],
                                "Profiles" : {
                                    "Testing" : [ "apigatewaycfdistro" ]
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "apigatewaycfdistro" : {
                    "apigateway" : {
                        "TestCases" : [ "apigatewaycfdistro" ]
                    }
                }
            },
            "TestCases" : {
                "apigatewaycfdistro" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "RestApi" : {
                                    "Name" : "apiXappXapigatewaycfdistro",
                                    "Type" : "AWS::ApiGateway::RestApi"
                                },
                                "Deployment" : {
                                    "Name" : "apiDeployXappXapigatewaycfdistroXrunId098",
                                    "Type" : "AWS::ApiGateway::Deployment"
                                }
                            },
                            "Output" : [
                                "apiXappXapigatewaycfdistro",
                                "apiXappXapigatewaycfdistroXroot",
                                "apiXappXapigatewaycfdistroXregion"
                            ]
                        }
                    }
                }
            }
        }
    /]

[/#macro]
