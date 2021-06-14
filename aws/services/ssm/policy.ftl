[#ftl]

[#function ssmSessionManagerPermission
    os="linux"
    region={ "Ref" : "AWS::Region" }]

    [#-- Account level Session Manager Resources --]
    [#local accountEncryptionKeyId = getAccountSSMSessionManagerKMSKeyId()]

    [#local logBucketId = formatAccountSSMSessionManagerLogBucketId()]
    [#local logBucketPrefix = formatAccountSSMSessionManagerLogBucketPrefix() ]

    [#local logGroupId = formatAccountSSMSessionManagerLogGroupId()]
    [#local logGroupName = formatAccountSSMSessionManagerLogGroupName()]

    [#return
        ec2SSMSessionManagerPermission(os) +
        ec2SSMAgentUpdatePermission(os, region) +
        getExistingReference(accountEncryptionKeyId)?has_content?then(
            cmkDecryptPermission(accountEncryptionKeyId) +
            [
                getPolicyStatement(
                    "kms:GenerateDataKey",
                    getReference(accountEncryptionKeyId, ARN_ATTRIBUTE_TYPE)
                )
            ],
            []
        ) +
        getExistingReference(logBucketId)?has_content?then(
            getS3Statement(
                [
                    "s3:PutObject"
                ],
                logBucketId,
                logBucketPrefix?remove_ending("/"),
                "*"
            ) +
            getS3BucketStatement(
                [
                    "s3:GetEncryptionConfiguration"
                ],
                logBucketId
            )+
            getExistingReference(accountEncryptionKeyId)?has_content?then(
                s3EncryptionAllPermission(
                    accountEncryptionKeyId,
                    logBucketId,
                    logBucketPrefix,
                    getExistingReference(logBucketId, REGION_ATTRIBUTE_TYPE)
                ),
                []
            ),
            []
        ) +
        getExistingReference(logGroupId)?has_content?then(
            cwLogsProducePermission( logGroupName ) +
            [
                getPolicyStatement(
                    "logs:DescribeLogGroups",
                    "*"
                )
            ],
            []
        )]
[/#function]
