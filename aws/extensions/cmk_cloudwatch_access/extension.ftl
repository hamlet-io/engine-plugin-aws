[#ftl]

[@addExtension
    id="cmk_cloudwatch_access"
    aliases=[
        "_cmk_cloudwatch_access"
    ]
    description=[
        "Grants access to a CMK from the CloudWatch Service"
    ]
    supportedTypes=[
        BASELINE_KEY_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_cmk_cloudwatch_access_deployment_setup occurrence ]

    [@Policy
        [
            getPolicyStatement(
                [
                    "kms:GenerateDataKey*",
                    "kms:Decrypt"
                ],
                "*"
                {
                    "Service" : "cloudwatch.amazonaws.com"
                },
                {
                    "StringEquals": {
                        "aws:SourceAccount" : {
                            "Ref": "AWS::AccountId"
                        }
                    }
                },
                true,
                "CloudWatch Service Principal Access"
            )
        ]
    /]

[/#macro]
