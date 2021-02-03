[#ftl]

[@addExtension
    id="cmk_cloudfront_access"
    aliases=[
        "_cmk_cloudfront_access"
    ]
    description=[
        "Grants access to a CMK from the CloudFront Service"
    ]
    supportedTypes=[
        BASELINE_KEY_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_cmk_cloudfront_access_deployment_setup occurrence ]

    [@Policy
        [
            getPolicyStatement(
                [
                    "kms:GenerateDataKey"
                ],
                "*"
                {
                     "Service" : "delivery.logs.amazonaws.com"
                },
                "",
                true,
                "CloudFront Log Delivery access"
            )
        ]
    /]

[/#macro]
