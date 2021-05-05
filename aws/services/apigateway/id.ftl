[#ftl]

[#-- Resources --]
[#assign AWS_APIGATEWAY_RESOURCE_TYPE = "apigateway"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_APIGATEWAY_SERVICE
    resource=AWS_APIGATEWAY_RESOURCE_TYPE
/]
[#assign AWS_APIGATEWAY_DEPLOY_RESOURCE_TYPE = "apiDeploy"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_APIGATEWAY_SERVICE
    resource=AWS_APIGATEWAY_DEPLOY_RESOURCE_TYPE
/]
[#assign AWS_APIGATEWAY_STAGE_RESOURCE_TYPE = "apiStage"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_APIGATEWAY_SERVICE
    resource=AWS_APIGATEWAY_STAGE_RESOURCE_TYPE
/]
[#assign AWS_APIGATEWAY_DOMAIN_RESOURCE_TYPE = "apiDomain"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_APIGATEWAY_SERVICE
    resource=AWS_APIGATEWAY_DOMAIN_RESOURCE_TYPE
/]
[#assign AWS_APIGATEWAY_AUTHORIZER_RESOURCE_TYPE = "apiAuthorizer"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_APIGATEWAY_SERVICE
    resource=AWS_APIGATEWAY_AUTHORIZER_RESOURCE_TYPE
/]
[#assign AWS_APIGATEWAY_BASEPATHMAPPING_RESOURCE_TYPE = "apiBasePathMapping"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_APIGATEWAY_SERVICE
    resource=AWS_APIGATEWAY_BASEPATHMAPPING_RESOURCE_TYPE
/]
[#assign AWS_APIGATEWAY_APIKEY_RESOURCE_TYPE = "apiKey"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_APIGATEWAY_SERVICE
    resource=AWS_APIGATEWAY_APIKEY_RESOURCE_TYPE
/]

[#assign AWS_APIGATEWAY_USAGEPLAN_RESOURCE_TYPE = "apiUsagePlan"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_APIGATEWAY_SERVICE
    resource=AWS_APIGATEWAY_USAGEPLAN_RESOURCE_TYPE
/]

[#assign AWS_APIGATEWAY_USAGEPLAN_MEMBER_RESOURCE_TYPE = "apiUsagePlanMember"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_APIGATEWAY_SERVICE
    resource=AWS_APIGATEWAY_USAGEPLAN_MEMBER_RESOURCE_TYPE
/]

[#assign AWS_APIGATEWAY_VPCLINK_RESOURCE_TYPE = "apiVPCLink" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_APIGATEWAY_SERVICE
    resource=AWS_APIGATEWAY_VPCLINK_RESOURCE_TYPE
/]

[#function formatDependentAPIGatewayAuthorizerId resourceId extensions...]
    [#return formatDependentResourceId(
                AWS_APIGATEWAY_AUTHORIZER_RESOURCE_TYPE,
                resourceId,
                extensions)]
[/#function]

[#function formatDependentAPIGatewayAPIKeyId resourceId extensions...]
    [#return formatDependentResourceId(
                AWS_APIGATEWAY_APIKEY_RESOURCE_TYPE,
                resourceId,
                extensions)]
[/#function]

[#function formatInvokeApiGatewayArn apiId stageName="" account={ "Ref" : "AWS::AccountId" }]
    [#return
        formatRegionalArn(
            "execute-api",
            formatTypedArnResource(
                getReference(apiId),
                valueIfContent(stageName + "/*", stageName, "*"),
                "/"
            )
        )
    ]
[/#function]
