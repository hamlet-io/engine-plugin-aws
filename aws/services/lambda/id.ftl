[#ftl]

[#-- Resources --]
[#assign AWS_LAMBDA_RESOURCE_TYPE = "lambda"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_LAMBDA_SERVICE
    resource=AWS_LAMBDA_RESOURCE_TYPE
/]
[#assign AWS_LAMBDA_FUNCTION_RESOURCE_TYPE = "lambda"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_LAMBDA_SERVICE
    resource=AWS_LAMBDA_FUNCTION_RESOURCE_TYPE
/]
[#assign AWS_LAMBDA_PERMISSION_RESOURCE_TYPE = "permission"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_LAMBDA_SERVICE
    resource=AWS_LAMBDA_PERMISSION_RESOURCE_TYPE
/]
[#assign AWS_LAMBDA_EVENT_SOURCE_TYPE = "source"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_LAMBDA_SERVICE
    resource=AWS_LAMBDA_EVENT_SOURCE_TYPE
/]
[#assign AWS_LAMBDA_VERSION_RESOURCE_TYPE = "lambdaVersion" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_LAMBDA_SERVICE
    resource=AWS_LAMBDA_VERSION_RESOURCE_TYPE
/]

[#function formatLambdaPermissionId occurrence extensions...]
    [#return formatResourceId(
                AWS_LAMBDA_PERMISSION_RESOURCE_TYPE,
                occurrence.Core.Id,
                extensions)]
[/#function]

[#function formatLambdaEventSourceId occurrence extensions...]
    [#return formatResourceId(
                AWS_LAMBDA_EVENT_SOURCE_TYPE,
                occurrence.Core.Id,
                extensions)]
[/#function]

[#function formatLambdaArn lambdaId account={ "Ref" : "AWS::AccountId" }]
    [#return
        formatRegionalArn(
            "lambda",
            getReference(AWS_PROVIDER, lambdaId))]
[/#function]
