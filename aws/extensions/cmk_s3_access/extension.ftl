[#ftl]

[@addExtension
    id="cmk_s3_access"
    aliases=[
        "_cmk_s3_access"
    ]
    description=[
        "Grants access to a CMK from the S3 Service"
    ]
    supportedTypes=[
        BASELINE_KEY_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_cmk_s3_access_deployment_setup occurrence ]

    [@Policy
        [
            getPolicyStatement(
                [
                    "kms:GenerateDataKey"
                ],
                "*"
                {
                    "Service" : "s3.amazonaws.com"
                },
                "",
                true,
                "S3 Access for Inventory Report storage"
            )
        ]
    /]

[/#macro]
