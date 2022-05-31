[#ftl]

[#function cmkDecryptPermission id]
    [#return
        [
            getPolicyStatement(
                "kms:Decrypt",
                getReference(id, ARN_ATTRIBUTE_TYPE))
        ]
    ]
[/#function]

[#function s3AccountEncryptionReadPermission bucketName bucketPrefix bucketRegion ]
    [#local accountEncryptionKeyId = formatAccountCMKTemplateId() ]

    [#if getExistingReference(accountEncryptionKeyId)?has_content ]
        [#return s3EncryptionReadPermission(
                    accountEncryptionKeyId,
                    bucketName,
                    bucketPrefix,
                    bucketRegion
        )]
    [#else]
        [#return []]
    [/#if]
[/#function]

[#function s3EncryptionAllPermission keyId bucketName bucketPrefix bucketRegion ]
    [#return s3EncryptionStatement(
                [
                    "kms:Decrypt",
                    "kms:DescribeKey",
                    "kms:Encrypt",
                    "kms:GenerateDataKey*",
                    "kms:ReEncrypt*"
                ],
                keyId,
                bucketName,
                bucketPrefix,
                bucketRegion
    )]
[/#function]

[#function s3EncryptionReadPermission keyId bucketName bucketPrefix bucketRegion ]
    [#return s3EncryptionStatement(
                [
                    "kms:Decrypt",
                    "kms:DescribeKey"
                ],
                keyId,
                bucketName,
                bucketPrefix,
                bucketRegion
    )]
[/#function]

[#function s3EncryptionKinesisPermission keyId bucketName bucketPrefix bucketRegion ]
    [#return s3EncryptionStatement(
                [
                    "kms:Decrypt",
                    "kms:GenerateDataKey"
                ],
                keyId,
                bucketName,
                bucketPrefix,
                bucketRegion
    )]
[/#function]

[#function s3EncryptionStatement actions keyId bucketName bucketPrefix bucketRegion ]
    [#return
        [
            getPolicyStatement(
                asArray(actions),
                getArn(keyId, false, bucketRegion),
                "",
                {
                    "StringLike" : {
                        "kms:EncryptionContext:aws:s3:arn" : "arn:aws:s3:::" + formatRelativePath(bucketName, bucketPrefix?ensure_ends_with("*") )
                    }
                }
            )
        ]
    ]
[/#function]

[#function kinesisStreamEncryptionStatement actions keyId kinesisStreamId ]
    [#return
        [
            getPolicyStatement(
                asArray(actions),
                getArn(keyId),
                "",
                {
                    "StringEquals" : {
                        "kms:EncryptionContext:aws:kinesis:arn" : getArn(kinesisStreamId)
                    }
                }
            )
        ]
    ]
[/#function]

[#function secretsManagerKMSStatement actions keyId secretId secretRegion ]

    [#-- Handle empty region value if attribute is not set --]
    [#if ! secretRegion?has_content ]
        [#local secretRegion = getRegion()]
    [/#if]

    [#return
        [
            getPolicyStatement(
                asArray(actions),
                getArn(keyId, false, secretRegion),
                "",
                {
                    "StringEquals" : {
                        "kms:ViaService" : { "Fn::Join" : [ ".", [ "secretsmanager", secretRegion, "amazonaws.com"] ] }
                    }
                }
            )
        ]
    ]
[/#function]
