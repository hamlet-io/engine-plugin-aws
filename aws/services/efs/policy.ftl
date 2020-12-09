[#ftl]

[#function getEfsStatement actions id="" accessPointId="" principals="" conditions=""]
    [#local result = [] ]

    [#local conditions =
        {
            "Bool": {
                "aws:SecureTransport": "true"
            }
        }
    ]

    [#if accessPointId?has_content ]
        [#local conditions +=
            {
                "StringEquals": {
                    "elasticfilesystem:AccessPointArn" : getReference(AWS_PROVIDER, accessPointId, ARN_ATTRIBUTE_TYPE)
                }
            }
        ]
    [/#if]

    [#if id?has_content]
        [#local result +=
            [
                getPolicyStatement(
                    actions,
                    formatRegionalArn("elasticfilesystem", formatRelativePath("file-system", getReference(AWS_PROVIDER, id))),
                    principals,
                    conditions)
            ]
        ]
    [#else]
        [#local result +=
            [
                getPolicyStatement(
                    actions,
                    "",
                    principals
                    conditions
                )
            ]
        ]
    [/#if]

    [return result]
[/#function]

[#function efsReadPermission id="" accessPointId="" principals="" conditions="" ]
    [#return
        getEfsStatement(
            [
                "elasticfilesystem:ClientMount"
            ],
            id,
            accessPointId,
            principals,
            conditions
        )
    ]
[/#function]

[#function efsWritePermission id="" accessPointId="" principals="" conditions=""]
    [#return
        getEfsStatement(
            [
                "elasticfilesystem:ClientMount",
                "elasticfilesystem:ClientWrite"
            ],
            id,
            accessPointId,
            principals,
            conditions
        )
    ]
[/#function]

[#function efsFullPermission id="" accessPointId="" principals="" conditions=""]
    [#return
        getEfsStatement(
            [
                "elasticfilesystem:ClientMount",
                "elasticfilesystem:ClientWrite",
                "elasticfilesystem:ClientRootAccess"
            ],
            id,
            accessPointId,
            principals,
            conditions
        )
    ]
[/#function]
