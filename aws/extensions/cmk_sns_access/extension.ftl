[#ftl]

[@addExtension
    id="cmk_sns_access"
    aliases=[
        "_cmk_sns_access"
    ]
    description=[
        "Grants access to a CMK from the SNS Service"
    ]
    supportedTypes=[
        BASELINE_KEY_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_cmk_sns_access_deployment_setup occurrence ]

    [@Policy
        [
            getPolicyStatement(
                [
                    "kms:GenerateDataKey*",
                    "kms:Decrypt"
                ],
                "*"
                {
                    "Service" : "sns.amazonaws.com"
                },
                "",
                true,
                "SNS Service Principal Access"
            )
        ]
    /]

[/#macro]
