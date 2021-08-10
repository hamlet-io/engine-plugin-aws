[#ftl]

[#function cwLogsProducePermission logGroupName=""]
    [#local logGroupArn = logGroupName?has_content?then(
                    formatRegionalArn(
                            "logs",
                            "log-group:" + logGroupName + "*"),
                    "*")]
    [#return
        [
            getPolicyStatement(
                [
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents",
                    "logs:DescribeLogGroups",
                    "logs:DescribeLogStreams"
                ],
                logGroupArn)
        ] +
        [
            getPolicyStatement(
                [
                    "cloudwatch:PutMetricData"
                ],
                "*",
                "",
                logGroupName?has_content?then(
                    {
                        "StringEquals": {
                            "cloudwatch:namespace": 
                                "CWAgent"+logGroupName?keep_before_last("/")?keep_before_last("/")
                        }
                    },
                    ""
                )
            )
        ] +
        [
            getPolicyStatement(
                [
                    "ec2:DescribeTags"
                ],
                "*")
        ]
    ]
[/#function]

[#function cwMetricsProducePermission namespace="*"]
    [#return
        [
            getPolicyStatement(
                [
                    "cloudwatch:PutMetricData"
                ],
                "*",
                "",
                (namespace != "*" )?then(
                    {
                        "StringEquals" : {
                            "cloudwatch:namespace" : namespace
                        }
                    },
                    {}
                )
            )
        ]
    ]
[/#function]

[#function cwLogsConfigurePermission ]
    [#return
        [
            getPolicyStatement(
                [
                    "logs:PutMetricFilter",
                    "logs:PutRetentionPolicy"
                ]
            )
        ]
    ]
[/#function]
