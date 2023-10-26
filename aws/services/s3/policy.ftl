[#ftl]

[#function getS3Statement actions bucket key="" object="" principals="" conditions={}]
    [#return
        [
            getPolicyStatement(
                actions,
                    ((getExistingReference(bucket)?has_content)?then(getExistingReference(bucket),bucket) +
                    key?has_content?then("/" + key, "") +
                    object?has_content?then("/" + object, ""))?ensure_starts_with("arn:aws:s3:::"),
                principals,
                conditions)
        ]
    ]
[/#function]

[#function getS3BucketStatement actions bucket key="" object="" principals="" conditions={} ]
    [#local s3PrefixCondition = {} ]
    [#if key?has_content || object?has_content ]
        [#if key?has_content && object != "*" ]
            [#local s3PrefixCondition =
                {
                    "StringLike" : {
                        "s3:prefix" : (key?has_content?then(key, "") + object?has_content?then("/" + object, ""))?remove_beginning("/")
                    }
                }
            ]
        [/#if]
    [/#if]
    [#return
        [
            getPolicyStatement(
                actions,
                    ((getExistingReference(bucket)?has_content)?then(getExistingReference(bucket),bucket))?ensure_starts_with("arn:aws:s3:::"),
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
                "s3:ListBucketVersions",
                "s3:GetBucketLocation"
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
                "s3:ListBucketVersions",
                "s3:GetBucketLocation"
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
                "s3:ListBucketVersions",
                "s3:GetBucketLocation"
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

[#function s3ListPermission bucket key="" object="*" principals="" conditions={}]
    [#return
        getS3Statement(
            "s3:List*",
            bucket,
            key,
            object,
            principals,
            conditions
        ) +
        getS3BucketStatement(
            [
                "s3:ListBucket",
                "s3:ListBucketVersions",
                "s3:GetBucketLocation"
            ],
            bucket,
            key,
            object,
            principals,
            conditions
        )

    ]
[/#function]

[#function s3ListBucketPermission bucket principals="" conditions={}]
    [#return
        getS3BucketStatement(
            [
                "s3:ListBucket",
                "s3:GetBucketLocation",
                "s3:GetBucketLocation"
            ],
            bucket,
            "",
            "",
            principals,
            conditions)]
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
                "s3:GetObjectVersionAcl",
                "s3:GetObjectVersionForReplication"
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
                "s3:PutObject",
                "s3:ReplicateObject",
                "s3:ReplicateDelete",
                "s3:ObjectOwnerOverrideToBucketOwner",
                "s3:ReplicateTags",
                "s3:GetObjectVersionTagging"
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


[#function s3InventorySerivcePermssion sourceBucket destBucket="" sourceAccount={ "Ref" : "AWS::AccountId" } ]
    [#return
        getS3Statement(
            [
                "s3:PutObject"
            ],
            sourceBucket,
            "*",
            "",
            {
                "Service" : "s3.amazonaws.com"
            },
            { } +
            destBucket?has_content?then(
                {
                    "ArnLike" : {
                        "aws:SourceArn" : getArn(destBucket)
                    },
                    "StringEquals" : {
                        "aws:SourceAccount" : sourceAccount,
                        "s3:x-amz-acl" : "bucket-owner-full-control"
                    }
                },
                {
                    "StringEquals" : {
                        "s3:x-amz-acl" : "bucket-owner-full-control"
                    }
                }
            )
        )
    ]
[/#function]
