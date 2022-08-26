[#ftl]


[#function iamPassRolePermission role ]
    [#return
        [
            getPolicyStatement(
                [
                    "iam:GetRole",
                    "iam:PassRole"
                ],
                role
            )
        ]
    ]
[/#function]

[#function iamStandardPolicies occurrence baselineIds ]
    [#local permissions = occurrence.Configuration.Solution.Permissions ]
    [#return
        valueIfTrue(
            cmkDecryptPermission(baselineIds["Encryption"]),
            permissions.Decrypt,
            []
        ) +
        valueIfTrue(
            s3ReadPermission(baselineIds["OpsData"], getSettingsFilePrefix(occurrence)) +
            s3ListPermission(baselineIds["OpsData"], getSettingsFilePrefix(occurrence)) +
            s3EncryptionReadPermission(
                baselineIds["Encryption"],
                getExistingReference(baselineIds["OpsData"], NAME_ATTRIBUTE_TYPE),
                getSettingsFilePrefix(occurrence),
                getExistingReference(baselineIds["OpsData"], REGION_ATTRIBUTE_TYPE)
            ) +

            [#-- Support transition between FullRelativePath and FullRelativeRawPath --]
            s3ReadPermission(baselineIds["OpsData"], occurrence.Core.FullRelativePath) +
            s3ListPermission(baselineIds["OpsData"], occurrence.Core.FullRelativePath) +
            s3EncryptionReadPermission(
                baselineIds["Encryption"],
                getExistingReference(baselineIds["OpsData"], NAME_ATTRIBUTE_TYPE),
                occurrence.Core.FullRelativePath,
                getExistingReference(baselineIds["OpsData"], REGION_ATTRIBUTE_TYPE)
            ),
            permissions.AsFile,
            []
        ) +
        valueIfTrue(
            s3AllPermission(baselineIds["AppData"], getAppDataFilePrefix(occurrence)) +
            s3EncryptionAllPermission(
                baselineIds["Encryption"],
                getExistingReference(baselineIds["AppData"], NAME_ATTRIBUTE_TYPE),
                getAppDataFilePrefix(occurrence),
                getExistingReference(baselineIds["AppData"], REGION_ATTRIBUTE_TYPE)
            ),
            permissions.AppData,
            []
        )
    ]
[/#function]
