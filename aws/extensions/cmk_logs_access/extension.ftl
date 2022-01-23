[#ftl]

[@addExtension
    id="cmk_logs_access"
    aliases=[
        "_cmk_logs_access"
    ]
    description=[
        "Grants access to a CMK from the CloudWatch Logs Service"
    ]
    supportedTypes=[
        BASELINE_KEY_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_cmk_logs_access_deployment_setup occurrence ]

    [@Policy
        [
            getPolicyStatement(
                [
                    "kms:Encrypt*",
                    "kms:Decrypt*",
                    "kms:ReEncrypt*",
                    "kms:GenerateDataKey*",
                    "kms:Describe*"
                ],
                "*"
                {
                    "Service" : {
                        "Fn::Sub" : [
                            r'logs.${Region}.amazonaws.com',
                            {
                                "Region" : {
                                    "Ref" : "AWS::Region"
                                }
                            }
                        ]
                    }
                },
                {
                    "ArnLike": {
                        "kms:EncryptionContext:aws:logs:arn":  {
                            "Fn::Sub" : [
                                r'arn:aws:logs:${Region}:${AWSAccountId}:*',
                                {
                                    "Region" : {
                                        "Ref" : "AWS::Region"
                                    },
                                    "AWSAccountId" : {
                                        "Ref" : "AWS::AccountId"
                                    }
                                }
                            ]
                        }
                    }
                },
                true,
                "CloudWatch Logs access to KMS for log storage"
            )
        ]
    /]

[/#macro]
