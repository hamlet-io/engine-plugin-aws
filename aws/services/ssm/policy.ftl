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
        ec2SSMSessionManagerPermission() +
        ec2SSMAgentUpdatePermission(os, region) +
        getExistingReference(AWS_PROVIDER, accountEncryptionKeyId)?has_content?then(
            cmkDecryptPermission(accountEncryptionKeyId) +
            [
                getPolicyStatement(
                    "kms:GenerateDataKey",
                    getReference(AWS_PROVIDER, accountEncryptionKeyId, ARN_ATTRIBUTE_TYPE)
                )
            ],
            []
        ) +
        getExistingReference(AWS_PROVIDER, logBucketId)?has_content?then(
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
            getExistingReference(AWS_PROVIDER, accountEncryptionKeyId)?has_content?then(
                s3EncryptionAllPermission(
                    accountEncryptionKeyId,
                    logBucketId,
                    logBucketPrefix,
                    getExistingReference(AWS_PROVIDER, logBucketId, REGION_ATTRIBUTE_TYPE)
                ),
                []
            ),
            []
        ) +
        getExistingReference(AWS_PROVIDER, logGroupId)?has_content?then(
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
