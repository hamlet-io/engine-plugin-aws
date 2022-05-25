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


[#assign AWS_KINESIS_DATA_STREAM_OUTPUT_MAPPINGS =
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
    resourceType=AWS_KINESIS_DATA_STREAM_RESOURCE_TYPE
    mappings=AWS_KINESIS_DATA_STREAM_OUTPUT_MAPPINGS
/]

[@addCWMetricAttributes
    resourceType=AWS_KINESIS_FIREHOSE_STREAM_RESOURCE_TYPE
    namespace="AWS/Firehose"
    dimensions={
        "DeliveryStreamName" : {
            "Output" : {
                "Attribute" : REFERENCE_ATTRIBUTE_TYPE
            }
        }
    }
/]

[#macro createKinesisDataStream id name streamMode retentionHours="" shardCount=1 keyId="" dependencies="" tags={}]
    [#local encryptionConfig = {}]

    [#if keyId?has_content]
        [#local encryptionConfig =
            {
                "EncryptionType" : "KMS",
                "KeyId" : getArn(keyId)
            }
        ]
    [/#if]

    [#switch streamMode?lower_case ]
        [#case "on-demand"]
        [#case "on_demand"]
            [#local streamMode = "ON_DEMAND"]
            [#break]
        [#case "provisioned"]
            [#local streamMode = "PROVISIONED"]
            [#break]

        [#default]
            [@fatal
                message="Invalid stream provisioning mode for data stream"
                context={
                    "Id": id,
                    "name": name,
                    "StreamingMode" : streamMode
                }
            /]
    [/#switch]

    [@cfResource
        id=id
        type="AWS::Kinesis::Stream"
        properties=
            {
                "Name" : name,
                "StreamModeDetails" : {
                    "StreamMode" : streamMode
                }
            } +
            attributeIfContent("RetentionPeriodHours", retentionHours) +
            attributeIfContent("ShardCount", shardCount) +
            attributeIfContent("StreamEncryption", encryptionConfig)
        tags=tags
        outputs=AWS_KINESIS_DATA_STREAM_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]

[#macro createFirehoseStream
        id
        destination
        name=""
        deliveryStreamType=""
        kinesisStreamSourceId=""
        roleId=""
        dependencies=""
        tags=[] ]

    [@cfResource
        id=id
        type="AWS::KinesisFirehose::DeliveryStream"
        properties=
            {} +
            attributeIfContent(
                "DeliveryStreamName",
                name
            ) +
            attributeIfContent(
                "DeliveryStreamType",
                deliveryStreamType
            ) +
            attributeIfContent(
                "KinesisStreamSourceConfiguration",
                kinesisStreamSourceId,
                {
                    "KinesisStreamARN" : getArn(kinesisStreamSourceId),
                    "RoleARN" : getArn(roleId)
                }
            ) +
            destination
        tags=tags
        outputs=KINESIS_FIREHOSE_STREAM_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]

[#function getLoggingFirehoseStreamResources id name fullPath destinationLinkId streamNamePrefix="" ]
    [#local streamId = formatResourceId(AWS_KINESIS_FIREHOSE_STREAM_RESOURCE_TYPE, id, destinationLinkId )]
    [#return
        {
            "stream" : {
                "Id" : streamId,
                "Arn": getReference(streamId, ARN_ATTRIBUTE_TYPE),
                "Name" : formatName(streamNamePrefix, name, destinationLinkId )?truncate_c(64, ""),
                "Type" : AWS_KINESIS_FIREHOSE_STREAM_RESOURCE_TYPE
            },
            "lg" : {
                "Id" : formatDependentResourceId(AWS_CLOUDWATCH_LOG_GROUP_RESOURCE_TYPE, streamId ),
                "Name" : formatAbsolutePath(fullPath, destinationLinkId),
                "Type" : AWS_CLOUDWATCH_LOG_GROUP_RESOURCE_TYPE
            },
            "lgStream" : {
                "Id" : formatDependentResourceId(AWS_CLOUDWATCH_LOG_GROUP_STREAM_RESOURCE_TYPE, streamId ),
                "Name" : "S3Delivery",
                "Type" : AWS_CLOUDWATCH_LOG_GROUP_STREAM_RESOURCE_TYPE
            },
            "role" : {
                "Id" : formatDependentResourceId(AWS_IAM_ROLE_RESOURCE_TYPE, streamId),
                "Type" : AWS_IAM_ROLE_RESOURCE_TYPE
            }
        }
    ]
[/#function]

[#macro setupLoggingFirehoseStream
    occurrence
    resourceDetails
    destinationLink
    bucketPrefix
    componentSubset
    cloudwatchEnabled=true
    loggingProfile={}
    processorId=""
    cmkKeyId=""
    dependencies=""
    version="v1"]

    [#local logPrefix  = {
            "Fn::Join" : [
                "/",
                [
                    bucketPrefix,
                    "Logs",
                    { "Ref" : "AWS::AccountId" },
                    occurrence.Core.FullRelativePath?ensure_ends_with("/")
                ]
            ]
        }]

    [#local errorPrefix  = {
            "Fn::Join" : [
                "/",
                [
                    bucketPrefix,
                    "Errors",
                    { "Ref" : "AWS::AccountId" },
                    occurrence.Core.FullRelativePath?ensure_ends_with("/")
                ]
            ]
        }]

    [#if destinationLink?is_hash && destinationLink?has_content]

        [#local destinationCore = destinationLink.Core ]
        [#local destinationConfiguration = destinationLink.Configuration ]
        [#local destinationResources = destinationLink.State.Resources ]
        [#local destinationSolution = destinationConfiguration.Solution ]

        [#-- defaults --]
        [#local isEncrypted = false]
        [#local bufferInterval = 60]
        [#local bufferSize = 1]
        [#local compressionFormat = "GZIP" ]
        [#local rolePolicies = []]
        [#local streamDestinationConfiguration = {}]

        [#switch destinationCore.Type]

            [#case BASELINE_DATA_COMPONENT_TYPE]
            [#case S3_COMPONENT_TYPE]

                [#-- Handle target encryption --]
                [#local isEncrypted =
                    destinationSolution.Encryption.Enabled &&
                    destinationSolution.Encryption.EncryptionSource == "EncryptionService" ]

                [#if isEncrypted && !(cmkKeyId?has_content)]
                    [@fatal
                        message="Destination is encrypted, but CMK not provided."
                        context=destinationLink
                    /]
                [/#if]

                [#-- Handle processor functions --]
                [#if processorId?has_content]
                    [#local streamProcessorArn = getArn(processorId)]
                [/#if]

                [#local bucket = destinationResources["bucket"]]

                [#local rolePolicies += [
                    getPolicyDocument(
                        s3KinesesStreamPermission(bucket.Id) +
                        s3AllPermission(bucket.Name, bucketPrefix) +
                        isEncrypted?then(
                            s3EncryptionKinesisPermission(
                                cmkKeyId,
                                bucket.Name,
                                bucketPrefix,
                                region
                            ),
                            []
                        ) +
                        processorId?has_content?then(
                            lambdaKinesisPermission(streamProcessorArn),
                            []
                        ),
                        "firehose"
                    )
                ]]

                [#local streamDestinationConfiguration +=
                    getFirehoseStreamS3Destination(
                        bucket.Id,
                        logPrefix,
                        errorPrefix,
                        bufferInterval,
                        bufferSize,
                        compressionFormat,
                        resourceDetails["role"].Id,
                        isEncrypted,
                        cmkKeyId,
                        getFirehoseStreamLoggingConfiguration(cloudwatchEnabled, resourceDetails["lg"].Name!"", resourceDetails["lgStream"].Name!""),
                        false,
                        {},
                        processorId?has_content?then([
                            getFirehoseStreamLambdaProcessor(
                                streamProcessorArn,
                                resourceDetails["role"].Id,
                                bufferInterval,
                                bufferSize
                            )
                        ],
                        [])
                    )]

                [#break]

            [#default]
                [@fatal
                    message="Invalid stream destination."
                    detail="Supported Destinations - S3"
                    context=destinationLink
                /]
                [#break]

        [/#switch]

        [#if cloudwatchEnabled ]
            [@setupLogGroup
                occurrence=occurrence
                logGroupId=resourceDetails["lg"].Id
                logGroupName=resourceDetails["lg"].Name
                loggingProfile=loggingProfile
                kmsKeyId=cmkKeyId
            /]

            [#if deploymentSubsetRequired("lg", true) && isPartOfCurrentDeploymentUnit(resourceDetails["lg"].Id)]
                [@createLogStream
                    id=resourceDetails["lgStream"].Id
                    name=resourceDetails["lgStream"].Name
                    logGroup=resourceDetails["lg"].Name
                    dependencies=resourceDetails["lg"].Id
                /]
            [/#if]
        [/#if]

        [#if deploymentSubsetRequired("iam", true)  &&
                isPartOfCurrentDeploymentUnit(resourceDetails["role"].Id)]
            [@createRole
                id=resourceDetails["role"].Id
                trustedServices=["firehose.amazonaws.com"]
                policies=rolePolicies
                tags=getOccurrenceTags(occurrence)
            /]
        [/#if]

        [#if deploymentSubsetRequired(componentSubset, true)]
            [@createFirehoseStream
                id=resourceDetails["stream"].Id
                name=resourceDetails["stream"].Name
                destination=streamDestinationConfiguration
                dependencies=cloudwatchEnabled?then(resourceDetails["lgStream"].Id, "")
            /]
        [/#if]
    [#else]
        [@fatal
            message="Destination Link is not a hash or is empty."
            context=destinationLink
        /]
    [/#if]

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
        compressionFormat
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
            "CompressionFormat" : compressionFormat?upper_case,
            "Prefix" : bucketPrefix?ensure_ends_with("/"),
            "RoleARN" : getReference(roleId, ARN_ATTRIBUTE_TYPE),
            "CloudWatchLoggingOptions" : loggingConfiguration,
            [#-- If encryption is turned on and then needs to be turned off, --]
            [#-- just omitting the EncryptionConfig attribute WON'T remove   --]
            [#-- the encryption config. It must be explicitly marked as not  --]
            [#-- required. The behaviour is inconsistent with the way most   --]
            [#-- templates work, but is needed for things to work.           --]
            "EncryptionConfiguration" :
                valueIfTrue(
                    {
                        "KMSEncryptionConfig" : {
                            "AWSKMSKeyARN" : getReference(kmsKeyId, ARN_ATTRIBUTE_TYPE)
                        }
                    },
                    encrypted,
                    {
                        "NoEncryptionConfig" : "NoEncryption"
                    }
                )
        }
    ]
[/#function]

[#-- Check if a prefix is using dynamic partitioning --]
[#function prefixRequiresDynamicPartitioning prefix]

    [#if prefix?is_string]
        [#return
            prefix?contains("!{partitionKeyFromQuery") ||
            prefix?contains("!{partitionKeyFromLambda")
        ]
    [/#if]

    [#if prefix?is_hash]
        [#list prefix?values as value]
            [#if prefixRequiresDynamicPartitioning(value) ]
                [#return true]
            [/#if]
        [/#list]
    [/#if]

    [#if prefix?is_sequence]
        [#list prefix as value]
            [#if prefixRequiresDynamicPartitioning(value) ]
                [#return true]
            [/#if]
        [/#list]
    [/#if]

    [#return false]
[/#function]

[#function getFirehoseStreamS3Destination
        bucketId
        bucketPrefix
        errorPrefix
        bufferInterval
        bufferSize
        compressionFormat
        roleId
        encrypted
        kmsKeyId
        loggingConfiguration
        backupEnabled
        backupS3Destination
        lambdaProcessor=[]
        dynamicPartitioningEnabled=false
        delimiter=""
]

[#local dynamicPartitioningRequired =
    dynamicPartitioningEnabled &&
    (
        delimiter?has_content ||
        prefixRequiresDynamicPartitioning(bucketPrefix) ||
        prefixRequiresDynamicPartitioning(errorPrefix)
    )
]

[#local processors =
    asArray(lambdaProcessor) +
    arrayIfTrue(
        getFirehoseStreamDelimiterProcessor(delimiter),
        dynamicPartitioningEnabled &&
        delimiter?has_content
    )
]

[#return
 {
     "ExtendedS3DestinationConfiguration" : {
        "BucketARN" : getArn(bucketId),
        "BufferingHints" : {
                "IntervalInSeconds" : bufferInterval,
                [#-- Dynamic partitioning has a higher minimum buffer size --]
                "SizeInMBs" : valueIfTrue(bufferSize, (!dynamicPartitioningRequired) || (bufferSize > 64), 64)
            },
        "CloudWatchLoggingOptions" : loggingConfiguration,
        "CompressionFormat" : compressionFormat?upper_case,
        "RoleARN" : getReference(roleId, ARN_ATTRIBUTE_TYPE),
        "S3BackupMode" : backupEnabled?then("Enabled", "Disabled"),
        [#-- If encryption is turned on and then needs to be turned off, --]
        [#-- just omitting the EncryptionConfig attribute WON'T remove   --]
        [#-- the encryption config. It must be explicitly marked as not  --]
        [#-- required. The behaviour is inconsistent with the way most   --]
        [#-- templates work, but is needed for things to work.           --]
        "EncryptionConfiguration" :
            valueIfTrue(
                {
                    "KMSEncryptionConfig" : {
                        "AWSKMSKeyARN" : getReference(kmsKeyId, ARN_ATTRIBUTE_TYPE)
                    }
                },
                encrypted,
                {
                    "NoEncryptionConfig" : "NoEncryption"
                }
            ),
        "DynamicPartitioningConfiguration" :
            getFirehoseStreamDynamicPartitioningConfiguration(
                dynamicPartitioningRequired
            )
    } +
    attributeIfContent(
        "ProcessingConfiguration",
        processors,
        {
            "Enabled" : true,
            "Processors" : processors
        }
    ) +
    attributeIfContent(
        "Prefix",
        bucketPrefix,
        bucketPrefix?is_string?then(
            bucketPrefix?ensure_ends_with("/"),
            bucketPrefix
        )
    ) +
    attributeIfContent(
        "ErrorOutputPrefix",
        errorPrefix,
        errorPrefix?is_string?then(
            errorPrefix?ensure_ends_with("/"),
            errorPrefix
        )
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

[#-- Add a delimiter between records --]
[#function getFirehoseStreamDelimiterProcessor delimiter ]

    [#return
        {
            "Type" : "AppendDelimiterToRecord",
            "Parameters" : [
                {
                    "ParameterName" : "Delimiter",
                    "ParameterValue" : delimiter
                }
            ]
        }
    ]

[/#function]


[#-- Configure dynamic partitioning --]
[#function getFirehoseStreamDynamicPartitioningConfiguration
    enabled=true
    retryDuration=90 ]

    [#return
        {
            "Enabled" : enabled,
            "RetryOptions" : {
                "DurationInSeconds" : retryDuration
            }
        }
    ]

[/#function]
