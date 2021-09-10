[#ftl]

[#-- https://docs.aws.amazon.com/pinpoint/latest/developerguide/security_iam_id-based-policy-examples.html#security_iam_id-based-policy-examples-access-one-project --]
[#function pinpointWriteProjectStatement projectId principals="" conditions={}]
    [#return
        [
            getPolicyStatement(
                "mobiletargeting:GetApps",
                formatRegionalArn("mobiletargeting", "*"),
                principals,
                conditions),
            getPolicyStatement(
                [
                    "mobiletargeting:Get*",
                    "mobiletargeting:List*",
                    "mobiletargeting:Create*",
                    "mobiletargeting:Update*",
                    "mobiletargeting:Put*"
                ],
                [
                    formatRegionalArn(
                        "mobiletargeting",
                        "apps/"+projectId
                    ),
                    formatRegionalArn(
                        "mobiletargeting",
                        "apps/"+projectId + "/*"
                    ),
                    formatRegionalArn(
                        "mobiletargeting",
                        "reports"
                    )
                ],
                principals,
                conditions)
        ]
    ]
[/#function]

