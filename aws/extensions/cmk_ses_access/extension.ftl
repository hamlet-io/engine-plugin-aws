[#ftl]

[@addExtension
    id="cmk_ses_access"
    aliases=[
        "_cmk_ses_access"
    ]
    description=[
        "Allows SES to access KMS for S3 storage"
    ]
    supportedTypes=[
        BASELINE_KEY_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_cmk_ses_access_deployment_setup occurrence ]

    [@Policy
        [
            getPolicyStatement(
                [
                    "kms:Encrypt",
                    "kms:Decrypt",
                    "kms:ReEncrypt*",
                    "kms:GenerateDataKey*",
                    "kms:DescribeKey"
                ],
                "*"
                {
                    "Service" : "ses.amazonaws.com"
                },
                {
                    "StringEquals": {
                        "aws:SourceAccount" : {
                            "Ref": "AWS::AccountId"
                        }
                    }
                },
                true,
                "SES Access to CMK"
            )
        ]
    /]

[/#macro]
