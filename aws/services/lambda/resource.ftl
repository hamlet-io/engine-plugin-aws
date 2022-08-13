[#ftl]

[#assign LAMBDA_FUNCTION_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "Attribute" : "Arn"
        },
        REGION_ATTRIBUTE_TYPE: {
            "Value" : { "Ref" : "AWS::Region" }
        }
    }
]

[@addCWMetricAttributes
    resourceType=AWS_LAMBDA_FUNCTION_RESOURCE_TYPE
    namespace="AWS/Lambda"
    dimensions={
        "FunctionName" : {
            "ResourceProperty" : "Name"
        }
    }
/]

[#assign LAMBDA_VERSION_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        VERSION_ATTRIBUTE_TYPE : {
            "Attribute" : "Version"
        }
    }
]

[#assign LAMBDA_ALIAS_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[#assign LAMBDA_PERMISSION_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[#assign LAMBDA_EVENT_SOURCE_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[#assign lambdaMappings =
    {
        AWS_LAMBDA_FUNCTION_RESOURCE_TYPE : LAMBDA_FUNCTION_OUTPUT_MAPPINGS,
        AWS_LAMBDA_VERSION_RESOURCE_TYPE : LAMBDA_VERSION_OUTPUT_MAPPINGS,
        AWS_LAMBDA_ALIAS_RESOURCE_TYPE : LAMBDA_ALIAS_OUTPUT_MAPPINGS,
        AWS_LAMBDA_PERMISSION_RESOURCE_TYPE : LAMBDA_PERMISSION_OUTPUT_MAPPINGS,
        AWS_LAMBDA_EVENT_SOURCE_TYPE : LAMBDA_EVENT_SOURCE_MAPPINGS
    }
]
[#list lambdaMappings as type, mappings]
    [@addOutputMapping
        provider=AWS_PROVIDER
        resourceType=type
        mappings=mappings
    /]
[/#list]

[#macro createLambdaFunction id settings roleId securityGroupIds=[] subnetIds=[] dependencies=""]
    [@cfResource
        id=id
        type="AWS::Lambda::Function"
        properties=
            {
                "Code" :
                    valueIfContent(
                        {
                            "ZipFile" : {
                                "Fn::Join" : [
                                    "\n",
                                    asFlattenedArray(
                                        (settings.ZipFile)![]
                                    )
                                ]
                            }
                        },
                        settings.ZipFile!"",
                        {
                            "S3Bucket" : settings.S3Bucket,
                            "S3Key" : settings.S3Key
                        }),
                "FunctionName" : settings.Name,
                "Description" : settings.Description,
                "Handler" : settings.Handler,
                "Role" : getReference(roleId, ARN_ATTRIBUTE_TYPE),
                "Runtime" : settings.RunTime
            } +
            attributeIfContent("Environment", (settings.Environment)!{}, { "Variables" : (settings.Environment)!{}}) +
            attributeIfTrue("MemorySize", settings.MemorySize > 0, settings.MemorySize) +
            attributeIfTrue("Timeout", settings.Timeout > 0, settings.Timeout) +
            attributeIfTrue(
                "KmsKeyArn",
                settings.Encrypted!false,
                getReference(settings.KMSKeyId, ARN_ATTRIBUTE_TYPE)
            ) +
            attributeIfContent(
                "VpcConfig",
                securityGroupIds,
                {
                    "SecurityGroupIds" : getReferences(securityGroupIds),
                    "SubnetIds" : getReferences(subnetIds)
                }
            ) +
            attributeIfTrue(
                "TracingConfig",
                settings.Tracing.Configured && settings.Tracing.Enabled && (settings.Tracing.Mode)?has_content,
                {
                    "Mode" :
                        valueIfTrue(
                            "Active",
                            (settings.Tracing.Mode!"") == "active",
                            "PassThrough")
                }
            ) +
            attributeIfTrue(
                "ReservedConcurrentExecutions",
                settings.ReservedExecutions >= 1,
                settings.ReservedExecutions
            ) +
            attributeIfContent(
                "Layers",
                _context.Layers,
                asFlattenedArray(_context.Layers)
            )

        outputs=LAMBDA_FUNCTION_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]

[#macro createLambdaVersion id
            targetId
            codeHash=""
            description=""
            dependencies=""
            outputId=""
            deletionPolicy=""
            updateReplacePolicy=""
            provisionedExecutions=-1 ]
    [@cfResource
        id=id
        type="AWS::Lambda::Version"
        properties=
            {
                "FunctionName" : getReference(targetId)
            } +
            attributeIfContent(
                "Description",
                description
            ) +
            attributeIfContent(
                "CodeSha256",
                codeHash
            ) +
            attributeIfTrue(
                "ProvisionedConcurrencyConfig",
                provisionedExecutions >= 1,
                {
                    "ProvisionedConcurrentExecutions" : provisionedExecutions
                }
            )
        outputs=LAMBDA_VERSION_OUTPUT_MAPPINGS
        outputId=outputId
        dependencies=dependencies
        updateReplacePolicy=updateReplacePolicy
        deletionPolicy=deletionPolicy
    /]
[/#macro]

[#macro createLambdaAlias id name
            functionId
            targetId
            description=""
            dependencies=""
            outputId=""
            deletionPolicy=""
            updateReplacePolicy=""
            provisionedExecutions=-1 ]
    [@cfResource
        id=id
        type="AWS::Lambda::Alias"
        properties=
            {
                "Name" : name,
                "FunctionName" : getReference(functionId),
                "FunctionVersion" : getReference(targetId, VERSION_ATTRIBUTE_TYPE)
            } +
            attributeIfContent(
                "Description",
                description
            ) +
            attributeIfTrue(
                "ProvisionedConcurrencyConfig",
                provisionedExecutions >= 1,
                {
                    "ProvisionedConcurrentExecutions" : provisionedExecutions
                }
            )
        outputs=LAMBDA_ALIAS_OUTPUT_MAPPINGS
        outputId=outputId
        dependencies=dependencies
        updateReplacePolicy=updateReplacePolicy
        deletionPolicy=deletionPolicy
    /]
[/#macro]

[#macro createLambdaPermission id targetId action="lambda:InvokeFunction" source={} sourcePrincipal="" sourceId="" dependencies=""]
    [@cfResource
        id=id
        type="AWS::Lambda::Permission"
        properties=
            {
                "FunctionName" : getArn(targetId),
                "Action" : action
            } +
            valueIfContent(
                source,
                source,
                {
                    "Principal" : sourcePrincipal,
                    "SourceArn" : getArn(sourceId)
                }
            )
        outputs=LAMBDA_PERMISSION_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]

[#macro createLambdaEventSource
        id
        targetId
        source
        enabled=true
        batchSize=""
        startingPosition=""
        functionResponseTypes=[]
        maximumBatchingWindow=0
        dependencies=[]]

    [@cfResource
        id=id
        type="AWS::Lambda::EventSourceMapping"
        properties=
            {
                "Enabled" : enabled,
                "EventSourceArn" : getArn(source),
                "FunctionName" : getReference(targetId)
            } +
            attributeIfContent("BatchSize", batchSize) +
            attributeIfContent("StartingPosition", startingPosition) +
            attributeIfContent("FunctionResponseTypes", asArray(functionResponseTypes)) +
            attributeIfTrue("MaximumBatchingWindowInSeconds", maximumBatchingWindow > 0, maximumBatchingWindow)
        outputs=LAMBDA_EVENT_SOURCE_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]
