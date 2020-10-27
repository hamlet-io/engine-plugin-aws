[#ftl]

[#function getS3Statement actions bucket key="" object="" principals="" conditions={}]
    [#return
        [
            getPolicyStatement(
                actions,
                "arn:aws:s3:::" +
                    (getExistingReference(bucket)?has_content)?then(getExistingReference(bucket),bucket) +
                    key?has_content?then("/" + key, "") +
                    object?has_content?then("/" + object, ""),
                principals,
                conditions)
        ]
    ]
[/#function]

[#function getS3BucketStatement actions bucket key="" object="" principals="" conditions={} ]
    [#local s3PrefixCondition = {} ]
    [#if key?has_content || object?has_content ]
        [#local s3PrefixCondition =
            {
                "StringLike" : {
                    "s3:prefix" : (key?has_content?then(key, "") + object?has_content?then("/" + object, ""))?remove_beginning("/")
                }
            }
        ]
    [/#if]
    [#return
        [
            getPolicyStatement(
                actions,
                "arn:aws:s3:::" +
                    (getExistingReference(bucket)?has_content)?then(getExistingReference(bucket),bucket),
                principals,
                conditions +
                    s3PrefixCondition

            )
        ]
    ]
[/#function]

[#function s3AllPermission bucket key="" object="*" principals="" conditions={}]
    [#return
        getS3Statement(
            [
                "s3:GetObject*",
                "s3:PutObject*",
                "s3:DeleteObject*",
                "s3:RestoreObject*",
                "s3:List*",
                "s3:Abort*"
            ]
            bucket,
            key,
            object,
            principals,
            conditions) +
        getS3BucketStatement(
            [
                "s3:ListBucket",
                "s3:ListBucketVersions"
            ]
            bucket,
            key,
            object,
            principals,
            conditions)

    ]
[/#function]

[#function s3ConsumePermission bucket key="" object="*" principals="" conditions={}]
    [#return
        getS3Statement(
            [
                "s3:GetObject*",
                "s3:DeleteObject*",
                "s3:List*"
            ],
            bucket,
            key,
            object,
            principals,
            conditions) +
        getS3BucketStatement(
            [
                "s3:ListBucket",
                "s3:ListBucketVersions"
            ],
            bucket,
            key,
            object,
            principals,
            conditions)

    ]
[/#function]

[#function s3ProducePermission bucket key="" object="*" principals="" conditions={} ]
    [#return
        getS3Statement(
            [
                "s3:PutObject*",
                "s3:Abort*",
                "s3:List*"
            ],
            bucket,
            key,
            object,
            principals,
            conditions) +
        getS3BucketStatement(
            [
                "s3:ListBucket",
                "s3:ListBucketVersions"
            ],
            bucket,
            key,
            object,
            principals,
            conditions)

    ]
[/#function]

[#function s3ReadPermission bucket key="" object="*" principals="" conditions={}]
    [#return
        getS3Statement(
            "s3:GetObject*",
            bucket,
            key,
            object,
            principals,
            conditions)]
[/#function]

[#function s3ReadBucketPermission bucket key="" object="*" principals={"AWS":"*"} conditions={}]
    [#return
        s3ReadPermission(
            bucket,
            key,
            object,
            principals,
            conditions)]
[/#function]


[#function s3WritePermission bucket key="" object="*" principals="" conditions={}]
    [#return
        getS3Statement(
            "s3:PutObject*",
            bucket,
            key,
            object,
            principals,
            conditions)]
[/#function]

[#function s3ListPermission bucket key="" object="" principals="" conditions={}]
    [#return
        getS3Statement(
            "s3:List*",
            bucket,
            key,
            object,
            principals,
            conditions) +
        getS3BucketStatement(
            [
                "s3:ListBucket",
                "s3:ListBucketVersions"
            ],
            bucket,
            key,
            object,
            principals,
            conditions
        )

    ]
[/#function]

[#function s3ListBucketPermission bucket]
    [#return
        getS3BucketStatement(
            [
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            bucket)]
[/#function]

[#function s3ReadBucketACLPermission bucket principals="" conditions={}]
    [#return
        getS3Statement(
            "s3:GetBucketAcl",
            bucket,
            "",
            "",
            principals,
            conditions)]
[/#function]

[#function s3ReplicaSourcePermission bucket prefix="" object="*"]
    [#return

        getS3Statement(
            [
                "s3:GetObjectVersion",
                "s3:GetObjectVersionAcl",
                "s3:GetObjectVersionTagging"
            ],
            bucket,
            prefix,
            object
        )
    ]
[/#function]

[#function s3ReplicationConfigurationPermission bucket ]
    [#return
        getS3BucketStatement(
            [
                "s3:GetReplicationConfiguration",
                "s3:ListBucket"
            ],
            bucket
        )
    ]
[/#function]

[#function s3ReplicaDestinationPermission bucket prefix="" object="*" ]
    [#return
        getS3Statement(
            [
                "s3:ReplicateObject",
                "s3:ReplicateDelete",
                "s3:ReplicateTags"
            ],
            bucket,
            prefix,
            object
        )
    ]
[/#function]


[#function s3KinesesStreamPermission bucket prefix="" object="*" ]
    [#return
        getS3Statement(
            [
                "s3:AbortMultipartUpload",
                "s3:PutObject"
            ],
            bucket,
            prefix,
            object
        ) + 
        getS3BucketStatement(
            [
                "s3:ListBucket",
                "s3:GetBucketLocation",
                "s3:ListBucketMultipartUploads"
            ],
            bucket
        )
    ]   
[/#function]

[#function getDataBucketRolePolicies bucketId bucketName encryptionKeyId role]

    [#local s3AllEncryptionPolicy  = s3EncryptionAllPermission(
        encryptionKeyId,
        bucketName,
        "*",
        getExistingReference(bucketId, REGION_ATTRIBUTE_TYPE))]

    [#local s3ReadEncryptionPolicy  = s3EncryptionReadPermission(
        encryptionKeyId,
        bucketName,
        "*",
        getExistingReference(bucketId, REGION_ATTRIBUTE_TYPE))]

    [#local linkPolicies = []]
    [#switch role]
        [#case "all"]
            [#local linkPolicies += [
                s3AllPermission(bucketId) + s3AllEncryptionPolicy
            ]]
            [#break]
        [#case "produce"]
            [#local linkPolicies += [
                s3ProducePermission(bucketId) + s3AllEncryptionPolicy
            ]]
            [#break]

        [#case "consume"]
            [#local linkPolicies += [
                s3ConsumePermission(bucketId) + s3ReadEncryptionPolicy
            ]]
            [#break]

        [#case "replicadestination"]
            [#local linkPolicies += [
                s3ReplicaDestinationPermission(bucketId) + s3ReadEncryptionPolicy
            ]]
            [#break]

        [#case "replicasource"]
            [#break]

        [#case "datafeed"]
            [#local linkPolicies += [
                s3KinesesStreamPermission(bucketId)
            ]]
            [#break]
    [/#switch]
    [#return linkPolicies]
[/#function]