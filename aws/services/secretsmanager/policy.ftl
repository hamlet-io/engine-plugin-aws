[#ftl]

[#function getSecretsManagerStatement actions id principals="" conditions="" allow=true sid="" ]
    [#return
        [
            getPolicyStatement(
                actions,
                getArn(id),
                principals,
                conditions,
                allow,
                sid
            )
        ]]
[/#function]


[#function secretsManagerReadPermission id kmsKeyId principals="" conditions={} allow=true sid="" ]
    [#return
        getSecretsManagerStatement(
            [
                "secretsmanager:GetSecretValue"
            ],
            id,
            principals,
            conditions,
            allow,
            sid
        ) +
        secretsManagerKMSStatement(
            [
                "kms:Decrypt"
            ],
            kmsKeyId,
            id,
            getReference(id, REGION_ATTRIBUTE_TYPE)
        )
    ]
[/#function]

[#function secretsManagerWritePermission id kmsKeyId principals="" conditions={} allow=true sid="" ]
    [#return
        getSecretsManagerStatement(
            [
                "secretsmanager:PutSecretValue",
                "secretsmanager:UpdateSecret"
            ],
            id,
            principals,
            conditions,
            allow,
            sid
        ) +
        secretsManagerKMSStatement(["kms:GenerateDataKey"], kmsKeyId, id, getReference(id, REGION_ATTRIBUTE_TYPE)) +
        [
            getPolicyStatement(
                [
                    "secretsmanager:GetRandomPassword"
                ],
                "*"
            )
        ]
    ]
[/#function]
