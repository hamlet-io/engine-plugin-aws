[#ftl]

[@addExtension
    id="cmk_sqs_access"
    aliases=[
        "_cmk_sqs_access"
    ]
    description=[
        "Grants access to a CMK from the SQS Service"
    ]
    supportedTypes=[
        BASELINE_KEY_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_cmk_sqs_access_deployment_setup occurrence ]

    [@Policy
        [
            getPolicyStatement(
                [
                    "kms:GenerateDataKey*",
                    "kms:Decrypt"
                ],
                "*"
                {
                    "Service" : "sqs.amazonaws.com"
                },
                {
                    "StringEquals": {
                        "aws:SourceAccount" : {
                            "Ref": "AWS::AccountId"
                        }
                    }
                },
                true,
                "SQS Service Principal Access"
            )
        ]
    /]

[/#macro]
