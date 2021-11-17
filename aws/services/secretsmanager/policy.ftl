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
        cmkDecryptPermission(kmsKeyId)
        ]
[/#function]
