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
    resourceType=AWS_KINESIS_FIREHOSE_STREAM_RESOURCE_TYPE
    mappings=KINESIS_FIREHOSE_STREAM_OUTPUT_MAPPINGS
/]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_KINESIS_DATA_STREAM_RESOURCE_TYPE
    mappings=AWS_KINESIS_DATA_STREAM_OUTPUT_MAPPINGS
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

[#macro createKinesisDataStream id name retentionHours="" shardCount=1 keyId="" dependencies=""]
    [#local encrpytionConfig = {}]
    [#if keyId?has_content]
        [#local encrpytionConfig = {
            "EncryptionType" : "KMS",
            "KeyId" : keyId }]
    [/#if]

    [@cfResource
        id=id
        type="AWS::Kinesis::Stream"
        properties=
            {
                "Name" : name
            } +
            attributeIfContent("RetentionPeriodHours", retentionHours) +
            attributeIfContent("ShardCount", shardCount) +
            attributeIfContent("StreamEncryption", encrpytionConfig)
        outputs=AWS_KINESIS_DATA_STREAM_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]

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

[#macro setupFirehoseStream 
    id
    lgPath
    destinationLink
    bucketPrefix
    errorPrefix
    cloudwatchEnabled=true
    processorId=""
    cmkKeyId=""
    streamNamePrefix=""
    dependencies=""]

    [#if destinationLink?is_hash && destinationLink?has_content]

        [#local destinationCore = destinationLink.Core ]
        [#local destinationConfiguration = destinationLink.Configuration ]
        [#local destinationResources = destinationLink.State.Resources ]
        [#local destinationSolution = destinationConfiguration.Solution ]
    
        [#local lg = {
            "Id" : formatLogGroupId(id),
            "Name" : lgPath }]

        [#local lgStream = {
            "Id" : formatResourceId(AWS_CLOUDWATCH_LOG_GROUP_STREAM_RESOURCE_TYPE, id),
            "Name" : formatDependentResourceId(AWS_CLOUDWATCH_LOG_GROUP_STREAM_RESOURCE_TYPE, lg.Id) }]

        [#local role = {
            "Id" : formatResourceId(AWS_IAM_ROLE_RESOURCE_TYPE, id) }]

        [#local stream = {
            "Id" : id,
            "Name" : formatName(streamNamePrefix, destinationCore.FullName) }]

        [#-- defaults --]
        [#local isEncrypted = false]
        [#local bufferInterval = 60]
        [#local bufferSize = 1]
        [#local rolePolicies = []]
        [#local streamDestinationConfiguration = {}]

        [#switch destinationCore.Type]

            [#case BASELINE_DATA_COMPONENT_TYPE]
            [#case S3_COMPONENT_TYPE]

                [#-- Handle target encryption --]
                [#local isEncrypted = destinationSolution.Encryption.Enabled]
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
                        bucketPrefix,
                        errorPrefix,
                        bufferInterval,
                        bufferSize,
                        role.Id,
                        isEncrypted,
                        cmkKeyId,
                        getFirehoseStreamLoggingConfiguration(cloudwatchEnabled, lg.Name!"", lgStream.Name!""),
                        false,
                        {},
                        processorId?has_content?then([
                            getFirehoseStreamLambdaProcessor(
                                streamProcessorArn,
                                role.Id,
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

        [#if cloudwatchEnabled]
            [@createLogGroup
                id=lg.Id
                name=lg.Name
            /]

            [@createLogStream
                id=lgStream.Id
                name=lgStream.Name
                logGroup=lg.Name
                dependencies=lg.Id
            /]
        [/#if]
        
        [@createRole
            id=role.Id
            trustedServices=["firehose.amazonaws.com"]
            policies=rolePolicies
        /]

        [@createFirehoseStream
            id=stream.Id
            name=stream.Name
            destination=streamDestinationConfiguration
            dependencies=cloudwatchEnabled?then(lgStream.Id, "")
        /]
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
        lambdaProcessor=[]
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
