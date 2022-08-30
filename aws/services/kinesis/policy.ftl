[#ftl]

[#function kinesisFirehoseStreamProducePermission id]
    [#return
        [
            getPolicyStatement(
                [
                    "firehose:PutRecord",
                    "firehose:PutRecordBatch"
                ],
                getReference(id, ARN_ATTRIBUTE_TYPE)
            )
        ]
    ]
[/#function]

[#function kinesisFirehoseStreamCloudwatchPermission id]
    [#return
        [
            getPolicyStatement(
                [
                    [#-- Full permissions required based on AWS documentation --]
                    [#-- https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/SubscriptionFilters.html#FirehoseExample --]
                    "firehose:*"
                ],
                getArn(id)
            )
        ]
    ]
[/#function]

[#function kinesisDataStreamConsumePermssion id]
    [#return [
        getPolicyStatement(
            [
                "kinesis:DescribeStream",
                "kinesis:DescribeStreamSummary",
                "kinesis:GetShardIterator",
                "kinesis:GetRecords",
                "kinesis:ListShards"
            ],
            getArn(id)
        )
    ]]
[/#function]


[#function kinesisDataStreamProducePermssion id]
    [#return [
        getPolicyStatement(
            [
                "kinesis:DescribeStream",
                "kinesis:DescribeStreamSummary",
                "kinesis:GetShardIterator",
                "kinesis:PutRecord",
                "kinesis:PutRecords"
            ],
            getArn(id)
        )
    ]]
[/#function]
