[#ftl]

[#assign KINESIS_FIREHOSE_STREAM_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "Attribute" : "Arn"
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_KINESIS_FIREHOSE_STREAM_RESOURCE_TYPE
    mappings=KINESIS_FIREHOSE_STREAM_OUTPUT_MAPPINGS
/]

[#assign metricAttributes +=
    {
        AWS_KINESIS_FIREHOSE_STREAM_RESOURCE_TYPE : {
            "Namespace" : "AWS/Firehose",
            "Dimensions" : {
                "DeliveryStreamName" : {
                    "Output" : REFERENCE_ATTRIBUTE_TYPE
                }
            }
        }
    }
]


[#macro createFirehoseStream id name destination dependencies="" ]
    [@cfResource
        id=id
        type="AWS::KinesisFirehose::DeliveryStream"
        properties=
            {
                "DeliveryStreamName" : name
            } +
            destination
        outputs=KINESIS_FIREHOSE_STREAM_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]

[#macro setupFirehoseStream id occurrence loggingProfile streamNamePrefix="" dependencies=""]
    
    [#local streamDestinationConfiguration = {}]
    [#local streamRolePolicies = []]
    [#local streamProcessorArn = ""]

    [#local baselineLinks = getBaselineLinks(occurrence, [ "Encryption" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local cmkKeyId = baselineComponentIds["Encryption"]]

    [#-- Process Logging Profile Links --]
    [#list loggingProfile.ForwardingRules!{} as id,forwardingRule ]
        [#list forwardingRule.Links?values as link]
            [#if link?is_hash]
                [#local linkTarget = getLinkTarget(occurrence, link, false) ]
                [@debug message="Link Target" context=linkTarget enabled=false /]
                [#if !linkTarget?has_content]
                    [#continue]
                [/#if]

                [#local linkTargetCore = linkTarget.Core ]
                [#local linkTargetConfiguration = linkTarget.Configuration ]
                [#local linkTargetResources = linkTarget.State.Resources ]
                [#local linkTargetAttributes = linkTarget.State.Attributes ]
                [#local linkTargetSolution = linkTargetConfiguration.Solution]

                [#switch linkTargetCore.Type]
                    [#case LAMBDA_FUNCTION_COMPONENT_TYPE]
                        [#if link.Role == "kinesis"]
                            [#local streamProcessorArn = linkTargetAttributes["ARN"]]
                        [/#if]
                        [#break]

                    [#case S3_COMPONENT_TYPE]
                        
                        [#local isEncrypted = linkTargetSolution.Encryption.Enabled]
                        [#local bucket = linkTargetResources["bucket"] ]
                        [#local prefix = formatRelativePath(occurrence.Core.FullRelativePath)]
                        [#local bufferInterval = 60]
                        [#local bufferSize = 1]
                        [#local errorPrefix = formatRelativePath("error", occurrence.Core.FullRelativePath)] 
                        [#local streamRoleId = formatResourceId(AWS_IAM_ROLE_RESOURCE_TYPE, id)]
                        [#break]

                    [#default]
                        [@fatal
                            message="Invalid stream destination or destination not found"
                            detail="Supported Destinations - S3"
                            context=occurrence
                        /]
                        [#break]
                [/#switch]
            [/#if]
        [/#list]
    [/#list]

    [#-- Validation --]
    [#if !streamProcessorArn?has_content]
        [@fatal
            message="Invalid Logging Profile. Profiles must contain at least one Log Processor."
            context={}
        /]
    [/#if]

    [#local streamRolePolicies += [
        getPolicyDocument(
            isEncrypted?then(
                s3EncryptionKinesisPermission(
                    cmkKeyId,
                    bucket.Name,
                    prefix,
                    region
                ),
                []
            ) +
            s3AllPermission(bucket.Name, bucketPrefix),
            "apigwbase"
        ),
        getPolicyDocument(
            s3KinesesStreamPermission(bucket.Id) +
            lambdaKinesisPermission(streamProcessorArn),
            "apigw"
        )
    ]]

    [#local streamDestinationConfiguration = 
        getFirehoseStreamS3Destination(
            bucket.Id,
            prefix,
            errorPrefix,
            bufferInterval,
            bufferSize,
            streamRoleId,
            isEncrypted,
            cmkKeyId,
            getFirehoseStreamLoggingConfiguration(false),
            false,
            {},
            [
                getFirehoseStreamLambdaProcessor(
                    streamProcessorArn,
                    streamRoleId,
                    bufferInterval,
                    bufferSize
                )
            ]
        )
    ]
    
    [@createRole
        id=streamRoleId
        trustedServices=["firehose.amazonaws.com"]
        policies=streamRolePolicies
    /]

    [@createFirehoseStream
        id=formatResourceId(AWS_KINESIS_FIREHOSE_STREAM_RESOURCE_TYPE, id)
        name=formatName(streamNamePrefix, occurrence.Core.FullName)
        destination=streamDestinationConfiguration
        dependencies=dependencies
    /]

[/#macro]

[#function getFirehoseStreamESDestination
        bufferInterval
        bufferSize
        esDomain
        roleId
        indexName
        indexRotation
        documentType
        retryDuration
        backupPolicy
        backupS3Destination
        loggingConfiguration
        lambdaProcessor ]

    [#return
        {
            "ElasticsearchDestinationConfiguration" : {
                "BufferingHints" : {
                    "IntervalInSeconds" : bufferInterval,
                    "SizeInMBs" : bufferSize
                },
                "DomainARN" : getArn(esDomain, true),
                "IndexName" : indexName,
                "IndexRotationPeriod" : indexRotation,
                "TypeName" : documentType,
                "RetryOptions" : {
                    "DurationInSeconds" : retryDuration
                },
                "RoleARN" : getReference(roleId, ARN_ATTRIBUTE_TYPE),
                "S3BackupMode" : backupPolicy,
                "S3Configuration" : backupS3Destination,
                "CloudWatchLoggingOptions" : loggingConfiguration
            } +
            attributeIfContent(
                "ProcessingConfiguration",
                lambdaProcessor,
                {
                    "Enabled" : true,
                    "Processors" : asArray(lambdaProcessor)
                }
            )
        }
    ]
[/#function]

[#function getFirehoseStreamBackupS3Destination
        bucketId
        bucketPrefix
        bufferInterval
        bufferSize
        roleId
        encrypted
        kmsKeyId
        loggingConfiguration
    ]

    [#return
        {
            "BucketARN" : getArn(bucketId),
            "BufferingHints" : {
                "IntervalInSeconds" : bufferInterval,
                "SizeInMBs" : bufferSize
            },
            "CompressionFormat" : "GZIP",
            "Prefix" : bucketPrefix?ensure_ends_with("/"),
            "RoleARN" : getReference(roleId, ARN_ATTRIBUTE_TYPE),
            "CloudWatchLoggingOptions" : loggingConfiguration
        } +
        attributeIfTrue(
            "EncryptionConfiguration",
            encrypted,
            {
                "KMSEncryptionConfig" : {
                    "AWSKMSKeyARN" : getReference(kmsKeyId, ARN_ATTRIBUTE_TYPE)
                }
            }
        )
    ]
[/#function]

[#function getFirehoseStreamS3Destination
        bucketId
        bucketPrefix
        errorPrefix
        bufferInterval
        bufferSize
        roleId
        encrypted
        kmsKeyId
        loggingConfiguration
        backupEnabled
        backupS3Destination
        lambdaProcessor
]

[#return
 {
     "ExtendedS3DestinationConfiguration" : {
        "BucketARN" : getArn(bucketId),
        "BufferingHints" : {
                "IntervalInSeconds" : bufferInterval,
                "SizeInMBs" : bufferSize
            },
        "CloudWatchLoggingOptions" : loggingConfiguration,
        "CompressionFormat" : "GZIP",
        "RoleARN" : getReference(roleId, ARN_ATTRIBUTE_TYPE),
        "S3BackupMode" : backupEnabled?then("Enabled", "Disabled")
    } +
    attributeIfContent(
        "ProcessingConfiguration",
        lambdaProcessor,
        {
            "Enabled" : true,
            "Processors" : asArray(lambdaProcessor)
        }
    ) +
    attributeIfContent(
        "Prefix",
        bucketPrefix,
        bucketPrefix?ensure_ends_with("/")
    ) +
    attributeIfContent(
        "ErrorOutputPrefix",
        errorPrefix,
        errorPrefix?ensure_ends_with("/")
    ) +
    attributeIfTrue(
        "EncryptionConfiguration",
        encrypted,
        {
            "KMSEncryptionConfig" : {
                "AWSKMSKeyARN" : getReference(kmsKeyId, ARN_ATTRIBUTE_TYPE)
            }
        }
    ) +
    attributeIfTrue(
        "S3BackupConfiguration"
        backupEnabled,
        backupS3Destination
    )
 }
]
[/#function]

[#function getFirehoseStreamLoggingConfiguration
        enabled
        logGroupName=""
        logStreamName="" ]

    [#return
        {
                "Enabled" : enabled
        } +
        enabled?then(
            {
                "LogGroupName" : logGroupName,
                "LogStreamName" : logStreamName
            },
            {}
        )
    ]
[/#function]

[#function getFirehoseStreamLambdaProcessor
    lambdaId
    roleId
    bufferInterval
    bufferSize ]

    [#return
        {
            "Type" : "Lambda",
            "Parameters" : [
                {
                    "ParameterName" : "BufferIntervalInSeconds",
                    "ParameterValue" : bufferInterval?c
                },
                {
                    "ParameterName" : "BufferSizeInMBs",
                    "ParameterValue" : bufferSize?c
                },
                {
                    "ParameterName" : "LambdaArn",
                    "ParameterValue" : getArn(lambdaId)
                },
                {
                    "ParameterName" : "RoleArn",
                    "ParameterValue" : getArn(roleId)
                }
            ]
        }
    ]

[/#function]
