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
                getReference(keyId, ARN_ATTRIBUTE_TYPE),
                "",
                {
                    "StringEquals" : {
                        "kms:ViaService" : formatDomainName( "s3", bucketRegion, "amazonaws.com" )
                    },
                    "StringLike" : {
                        "kms:EncryptionContext:aws:s3:arn" : "arn:aws:s3:::" + formatRelativePath(bucketName, bucketPrefix?ensure_ends_with("*") )
                    }
                }
            )
        ]
    ]
[/#function]
