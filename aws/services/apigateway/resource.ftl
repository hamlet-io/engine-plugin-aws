[#ftl]

[#assign APIGATEWAY_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ROOT_ATTRIBUTE_TYPE : {
            "Attribute" : "RootResourceId"
        },
        REGION_ATTRIBUTE_TYPE: {
            "Value" : { "Ref" : "AWS::Region" }
        }
    }
]

[#assign metricAttributes +=
    {
        AWS_APIGATEWAY_RESOURCE_TYPE : {
            "Namespace" : "AWS/ApiGateway",
            "Dimensions" : {
                "ApiName" : {
                    "ResourceProperty" : "Name"
                },
                "Stage" : {
                    "OtherResourceProperty" : {
                        "Id" : "apistage",
                        "Property" : "Name"
                    }
                }
            }
        }
    }
]

[#assign APIGATEWAY_APIKEY_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_APIGATEWAY_RESOURCE_TYPE
    mappings=APIGATEWAY_OUTPUT_MAPPINGS
/]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_APIGATEWAY_APIKEY_RESOURCE_TYPE
    mappings=APIGATEWAY_APIKEY_OUTPUT_MAPPINGS
/]

[#function formatInvokeApiGatewayArn apiId stageName="" account={ "Ref" : "AWS::AccountId" }]
    [#return
        formatRegionalArn(
            "execute-api",
            formatTypedArnResource(
                getReference(AWS_PROVIDER, apiId),
                valueIfContent(stageName + "/*", stageName, "*"),
                "/"
            )
        )
    ]
[/#function]

[#function formatAuthorizerApiGatewayArn apiId authorizerId="" account={ "Ref" : "AWS::AccountId" }]
    [#return
        formatRegionalArn(
            "execute-api",
            {
                "Fn::Join": [
                    "/",
                    [
                        getReference(AWS_PROVIDER, apiId),
                        "authorizers",
                        valueIfContent(getReference(AWS_PROVIDER, authorizerId),authorizerId,"*")
                    ]
                ]
            }
        )
    ]
[/#function]

[#macro createAPIKey id name enabled=true distinctId=false description="" dependencies="" ]
    [@cfResource
        id=id
        type="AWS::ApiGateway::ApiKey"
        properties=
            {
                "Enabled" : enabled,
                "GenerateDistinctId" : distinctId,
                "Name" : name
            } +
            attributeIfContent("Description", description)
        outputs=APIGATEWAY_APIKEY_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]

[#assign APIGATEWAY_USAGEPLAN_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_APIGATEWAY_USAGEPLAN_RESOURCE_TYPE
    mappings=APIGATEWAY_USAGEPLAN_OUTPUT_MAPPINGS
/]

[#macro createAPIUsagePlan id name stages=[] quotaSettings={} dependencies="" ]
    [@cfResource
        id=id
        type="AWS::ApiGateway::UsagePlan"
        properties=
            {
                "ApiStages" : stages,
                "UsagePlanName" : name
            } +
            attributeIfContent("Quota", quotaSettings)
        outputs=APIGATEWAY_USAGEPLAN_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]

[#macro createAPIUsagePlanMember id planId apikeyId dependencies="" ]
    [@cfResource
        id=id
        type="AWS::ApiGateway::UsagePlanKey"
        properties=
            {
                "KeyId" : getReference(AWS_PROVIDER, apikeyId),
                "KeyType" : "API_KEY",
                "UsagePlanId" : getReference(AWS_PROVIDER, planId)
            }
        outputs={}
        dependencies=dependencies
    /]
[/#macro]


