[#ftl]

[#function getS3LifecycleExpirationRule days prefix="" enabled=true]
    [#return
        [
            {
                "Status" : enabled?then("Enabled","Disabled")
            } +
            attributeIfContent("Prefix", prefix) +
            attributeIfTrue("ExpirationInDays", days?is_number, days) +
            attributeIfTrue("ExpirationDate", !(days?is_number), days)
        ]
    ]
[/#function]

[#function getS3LifecycleRule
        expirationdays=""
        transitiondays=""
        prefix=""
        enabled=true
        noncurrentexpirationdays=""
        noncurrenttransitiondays="" ]

    [#-- Alias overrides - Expiration --]
    [#if expirationdays?is_string ]
        [#switch expirationdays ]
            [#case "_operations" ]
                [#local expirationTime = operationsExpiration]
                [#break ]
            [#case "_data" ]
                [#local expirationTime = dataExpiration ]
                [#break]
            [#case "_flowlogs" ]
                [#local expirationTime = flowlogsExpiration ]
                [#break]
            [#default]
                [#local expirationTime = expirationdays]
        [/#switch]
    [#else]
        [#local expirationTime = expirationdays ]
    [/#if]

    [#-- Alias overrides - Transition --]
    [#if transitiondays?is_string ]
        [#switch transitiondays ]
            [#case "_operations" ]
                [#local transitionTime = operationsOffline]
                [#break ]
            [#case "_data" ]
                [#local transitionTime = dataOffline ]
                [#break]
            [#case "_flowlogs" ]
                [#local transitionTime = flowlogsOffline ]
                [#break]
            [#default]
                [#local transitionTime = transitiondays]
        [/#switch]
    [#else]
        [#local transitionTime = transitiondays ]
    [/#if]

    [#if expirationTime?has_content && !(noncurrentexpirationdays?has_content)]
        [#local noncurrentexpirationdays = expirationTime ]
    [/#if]

    [#if transitionTime?has_content && !(noncurrenttransitiondays?has_content)]
        [#local noncurrenttransitiondays = transitionTime ]
    [/#if]

    [#if transitionTime?has_content || expirationTime?has_content ||
            noncurrentexpirationdays?has_content || noncurrenttransitiondays?has_content ]
        [#return
            [
                {
                    "Status" : enabled?then("Enabled","Disabled")
                } +
                attributeIfContent("Prefix", prefix) +
                (expirationTime?has_content)?then(
                    attributeIfTrue("ExpirationInDays", expirationTime?is_number, expirationTime) +
                    attributeIfTrue("ExpirationDate", !(expirationTime?is_number), expirationTime),
                    {}
                ) +
                (transitionTime?has_content)?then(
                    {
                        "Transitions" : [
                            {
                                "StorageClass" : "GLACIER"
                            } +
                            attributeIfTrue("TransitionInDays", transitionTime?is_number, transitionTime) +
                            attributeIfTrue("TransitionDate", !(transitionTime?is_number), transitionTime)
                        ]
                    },
                    {}
                ) +
                attributeIfContent("NoncurrentVersionExpirationInDays", noncurrentexpirationdays) +
                (noncurrenttransitiondays?has_content)?then(
                    {
                        "NoncurrentVersionTransitions" : [
                            {
                                "StorageClass" : "GLACIER",
                                "TransitionInDays" : noncurrenttransitiondays
                            }
                        ]
                    },
                    {}
                )
            ]
        ]
    [#else]
        [#return []]
    [/#if]
[/#function]

[#function getS3LoggingConfiguration logBucket prefix ]
    [#return
        {
            "DestinationBucketName" : logBucket,
            "LogFilePrefix" : "s3/" + prefix + "/"
        }
    ]
[/#function]

[#function getS3Notification destId destResourceType event prefix="" suffix="" ]

    [#local filterRules = [] ]
    [#if prefix?has_content ]
        [#local filterRules +=
            [ {
                "Name" : "prefix",
                "Value" : prefix
            }] ]
    [/#if]

    [#if suffix?has_content ]
        [#local filterRules +=
            [
                {
                    "Name" : "suffix",
                    "Value" : suffix
                }
            ]
        ]
    [/#if]

    [#-- Aliases for notification events --]
    [#switch event ]
        [#case "create" ]
            [#local event = "s3:ObjectCreated:*" ]
            [#break]
        [#case "delete" ]
            [#local event = "s3:ObjectRemoved:*" ]
            [#break]
        [#case "restore" ]
            [#local event ="s3:ObjectRestore:*"]
            [#break]
        [#case "reducedredundancy" ]
            [#local event = "s3:ReducedRedundancyLostObject" ]
            [#break]
    [/#switch]

    [#local collectionKey = ""]
    [#local destKey = ""]

    [#switch destResourceType ]
        [#case AWS_SQS_RESOURCE_TYPE ]
            [#local destKey = "Queue" ]
            [#local collectionKey = "QueueConfigurations" ]
            [#break]

        [#case AWS_SNS_TOPIC_RESOURCE_TYPE ]
            [#local destKey = "Topic" ]
            [#local collectionKey = "TopicConfigurations" ]
            [#break]

        [#case AWS_LAMBDA_FUNCTION_RESOURCE_TYPE ]
            [#local destKey = "Function" ]
            [#local collectionKey = "LambdaConfigurations"]
            [#break]

        [#default]
            [@fatal
                message="Unsupported destination resource type"
                context={ "Id" : destId, "Type" : destResourceType }
            /]
    [/#switch]

    [#return
        [
            {
                "Type" : collectionKey,
                "Notification" : {
                        "Event" : event,
                        destKey : getReference(destId, ARN_ATTRIBUTE_TYPE )
                    } +
                    attributeIfContent(
                        "Filter",
                        filterRules,
                        {
                            "S3Key" :{
                                "Rules" : filterRules
                            }
                        }
                    )
            }
        ]
    ]
[/#function]

[#function getS3WebsiteConfiguration index error redirectTo="" redirectProtocol=""]
    [#-- If redirecting, only the redirection info can be provided --]
    [#if redirectTo?has_content]
        [#return
            {
                "RedirectAllRequestsTo" : {
                    "HostName" : redirectTo
                } +
                attributeIfContent("Protocol", redirectProtocol)
            }
        ]
    [#else]
        [#return
            {
                "IndexDocument" : index
            } +
            attributeIfContent("ErrorDocument", error)
        ]
    [/#if]
[/#function]

[#function getS3ReplicationConfiguration
    roleId
    replicationRules
    ]
    [#return
        {
            "Role" : getReference(roleId, ARN_ATTRIBUTE_TYPE),
            "Rules" : asArray(replicationRules)
        }
    ]
[/#function]

[#function getS3ReplicationRuleFilter prefix="" tags={} ]

    [#if (prefix?has_content && tags?has_content) || tags?values?size > 1 ]

        [#return {
            "And": {} +
                attributeIfContent(
                    "Prefix",
                    prefix
                )
                +
                attributeIfContent(
                    "TagFilters",
                    tags,
                    tags?keys?map(
                        x -> {
                            "Key": x,
                            "Value": tags[x]
                        }
                    )
                )
        }]
    [#else]
        [#return {} +
            attributeIfContent(
                "Prefix",
                prefix
            ) +
            attributeIfContent(
                "TagFilter",
                tags,
                tags?keys?map(
                    x -> {
                        "Key": x,
                        "Value": tags[x]
                    }
                )[0]
            )]
    [/#if]
[/#function]

[#function getS3ReplicationRule
    destinationBucket
    enabled
    prefix
    encryptReplica
    replicaKMSKeyId=""
    replicationDestinationAccountId=""
    filter={}
    priority=0
]
    [#local deleteMarkerReplication = "NotRequired" ]
    [#if filter?has_content ]
        [#if (filter.And.TagFilter)?? || (filter.TagFilter)?? ]
            [#local deleteMarkerReplication = "Disabled"]
        [#elseif (filter.And.Prefix)?? || (filter.Prefix)?? ]
            [#local deleteMarkerReplication = "Enabled"]
        [/#if]
    [/#if]

    [#local destinationEncryptionConfiguration = {}]
    [#if encryptReplica && replicaKMSKeyId?has_content]
        [#local destinationEncryptionConfiguration = {
            "ReplicaKmsKeyID" : getArn(replicaKMSKeyId)
        }]
    [/#if]

    [#local crossAccountReplication = false ]
    [#if replicationDestinationAccountId?has_content
            && replicationDestinationAccountId != accountObject.ProviderId ]
        [#local crossAccountReplication = true ]
    [/#if]

    [#return
        {
            "Status" : enabled?then(
                "Enabled",
                "Disabled"
            ),
            "Destination" : {
                "Bucket" : getArn(destinationBucket)
            } +
            attributeIfContent(
                "EncryptionConfiguration",
                destinationEncryptionConfiguration
            ) +
            attributeIfTrue(
                "AccessControlTranslation",
                crossAccountReplication,
                {
                    "Owner" : "Destination"
                }
            ) +
            attributeIfTrue(
                "Account",
                crossAccountReplication,
                replicationDestinationAccountId
            )
        } +
        encryptReplica?then(
            {
                "SourceSelectionCriteria" : {
                    "SseKmsEncryptedObjects" : {
                        "Status" : "Enabled"
                    }
                }
            },
            {}
        ) +
        attributeIfContent(
            "Prefix",
            prefix
        ) +
        attributeIfContent(
            "Filter",
            filter
        ) +
        attributeIfTrue(
            "Priority",
            priority > 0,
            priority
        ) +
        attributeIfTrue(
            "DeleteMarkerReplication",
            deleteMarkerReplication != "NotRequired",
            {
                "Status": deleteMarkerReplication
            }
        )
    ]
[/#function]

[#function getS3InventoryReportConfiguration
    inventoryId
    inventoryFormat
    destinationBucketArn
    scheduleFrequency
    sourcePrefix=""
    destinationPrefix=""
    includeVersions=false
    ]

    [#return
        {
            "Destination" : {
                "BucketAccountId" : accountObject.ProviderId,
                "BucketArn" : getArn(destinationBucketArn),
                "Format" : inventoryFormat
            } +
            attributeIfContent(
                "Prefix",
                destinationPrefix
            ),
            "Enabled" : true,
            "Id" : inventoryId,
            "IncludedObjectVersions" : includeVersions?then("All", "Current"),
            "ScheduleFrequency" : scheduleFrequency
        } +
        attributeIfContent(
            "Prefix",
            sourcePrefix
        )
    ]
[/#function]

[#function getS3ObjectOwnershipConfiguration
    ownership=""
    ]

    [#local result = {} ]
    [#if ownership?has_content]
        [#switch ownership ]
            [#case "owner" ]
                [#local objectOwner = "BucketOwnerEnforced" ]
                [#break]

            [#case "ownerpreferred" ]
                [#local objectOwner = "BucketOwnerPreferred" ]
                [#break]

            [#case "writer" ]
                [#local objectOwner = "ObjectWriter" ]
                [#break]

            [#default]
                [#local objectOwner = "HamletFatal: Unsupported bucket object ownership of " + ownership]
        [/#switch]

        [#local result =
            {
                "Rules" : [
                    {
                        "ObjectOwnership" : objectOwner
                    }
                ]
            }
        ]

    [/#if]

    [#return result]
[/#function]

[#assign S3_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        NAME_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "Attribute" : "Arn"
        },
        DNS_ATTRIBUTE_TYPE : {
            "Attribute" : "DomainName"
        },
        URL_ATTRIBUTE_TYPE : {
            "Attribute" : "WebsiteURL"
        },
        REGION_ATTRIBUTE_TYPE: {
            "Value" : { "Ref" : "AWS::Region" }
        }
    }
]

[#-- Default policy applied will essentially disable public ACLs and lock down cross account access if a bucket is public --]
[#-- https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html --]
[#function getPublicAccessBlockConfiguration
        blockPublicPolicy=true
        blockPublicAcls=true
        ignorePublicAcls=true
        restrictPublicBuckets=true
    ]

    [#return
        {
            "BlockPublicAcls" : blockPublicAcls,
            "BlockPublicPolicy" : blockPublicPolicy,
            "IgnorePublicAcls" : ignorePublicAcls,
            "RestrictPublicBuckets" : restrictPublicBuckets
        }
    ]
[/#function]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_S3_RESOURCE_TYPE
    mappings=S3_OUTPUT_MAPPINGS
/]


[#macro createS3Bucket
        id
        name
        encrypted=false
        encryptionSource="aws:kms"
        kmsKeyId=""
        lifecycleRules=[]
        notifications=[]
        versioning=false
        websiteConfiguration={}
        replicationConfiguration={}
        publicAccessBlockConfiguration={}
        cannedACL=""
        CORSBehaviours=[]
        inventoryReports=[]
        objectOwnershipConfiguration={}
        dependencies=""
        outputId=""
        tags={}
    ]

    [#local loggingConfiguration = {} ]

    [#-- Enabling logging on the audit bucket would cause an infinite loop --]
    [#if formatAccountS3Id("audit") != id ]
        [#if getExistingReference(formatAccountS3Id("audit"), "", getRegion() )?has_content ]
            [#local loggingConfiguration = getS3LoggingConfiguration(
                                    getExistingReference(formatAccountS3Id("audit")),
                                    name) ]
        [/#if]
    [/#if]

    [#local versionConfiguration={}]
    [#if versioning ]
        [#local versionConfiguration = {
            "Status" : "Enabled"
        } ]
    [/#if]

    [#local CORSRules = [] ]
    [#list CORSBehaviours as behaviour ]
        [#local CORSBehaviour = CORSProfiles[behaviour] ]
        [#if CORSBehaviour?has_content ]
            [#local CORSRules += [
                {
                    "Id" : behaviour,
                    "AllowedHeaders" : CORSBehaviour.AllowedHeaders,
                    "AllowedMethods" : CORSBehaviour.AllowedMethods,
                    "AllowedOrigins" : CORSBehaviour.AllowedOrigins,
                    "ExposedHeaders" : CORSBehaviour.ExposedHeaders,
                    "MaxAge" : (CORSBehaviour.MaxAge)?c
                }
            ]]
        [/#if]
    [/#list]

    [#local notificationRules = {}]
    [#list notifications as notification ]
        [#local notificationType = notification.Type ]
        [#local notificationTypeRules = notificationRules[ notificationType ]![]]

        [#local notificationRules = notificationRules +
            {
                notificationType : notificationTypeRules + [ notification["Notification"] ]
            }]
    [/#list]

    [#local bucketEncryptionConfig = {} ]
    [#local encryptionMode = ""]
    [#if encrypted ]

        [#switch encryptionSource?lower_case ]
            [#case "localservice" ]
            [#case "aes256" ]
                [#local encryptionMode = "AES256" ]
                [#break]

            [#case "encryptionservice" ]
            [#case "aws:kms" ]
                [#local encryptionMode = "aws:kms" ]
                [#break]

            [#default]
                [@fatal
                    message="Unsupported S3 Encryption Source"
                    detail={
                        "BucketId" : id,
                        "Name" : name,
                        "EncryptionSource": encryptionSource
                    }
                /]
        [/#switch]

        [#local bucketEncryptionConfig = {
            "ServerSideEncryptionConfiguration" : [
                {
                    "ServerSideEncryptionByDefault" : {
                        "SSEAlgorithm" : encryptionMode
                    } +
                    attributeIfTrue(
                        "KMSMasterKeyID",
                        ( encryptionMode == "aws:kms" ),
                        getArn(kmsKeyId)
                    )
                }
            ]
        }]
    [/#if]

    [@cfResource
        id=id
        type="AWS::S3::Bucket"
        properties=
            {
                "BucketName" : name
            } +
            attributeIfContent(
                "LifecycleConfiguration",
                lifecycleRules,
                {
                    "Rules" : lifecycleRules
                }) +
            attributeIfContent(
                "NotificationConfiguration",
                notificationRules
            ) +
            attributeIfContent(
                "WebsiteConfiguration",
                websiteConfiguration
            ) +
            attributeIfContent(
                "LoggingConfiguration",
                loggingConfiguration
            ) +
            attributeIfContent(
                "AccessControl",
                cannedACL
            ) +
            attributeIfContent(
                "VersioningConfiguration",
                versionConfiguration
            ) +
            attributeIfContent(
                "CorsConfiguration",
                CORSRules,
                {
                    "CorsRules" : CORSRules
                }
            ) +
            attributeIfContent(
                "ReplicationConfiguration",
                replicationConfiguration
            ) +
            attributeIfTrue(
                "BucketEncryption",
                encrypted,
                bucketEncryptionConfig
            ) +
            attributeIfContent(
                "InventoryConfigurations",
                inventoryReports
            ) +
            attributeIfContent(
                "PublicAccessBlockConfiguration",
                publicAccessBlockConfiguration
            ) +
            attributeIfContent(
                "OwnershipControls",
                objectOwnershipConfiguration
            )
        tags=tags
        outputs=S3_OUTPUT_MAPPINGS
        outputId=outputId
        dependencies=dependencies
    /]
[/#macro]

[#macro createBucketPolicy id bucketId statements dependencies=[] ]
    [@cfResource
        id=id
        type="AWS::S3::BucketPolicy"
        properties=
            {
                "Bucket" : getReference(bucketId)
            } +
            getPolicyDocument(statements)
        outputs={}
        dependencies=dependencies
    /]
[/#macro]
