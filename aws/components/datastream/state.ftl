[#ftl]

[#macro aws_datastream_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local streamId = formatResourceId(AWS_KINESIS_DATA_STREAM_RESOURCE_TYPE, core.Id)]

    [#local baselineLinks = getBaselineLinks(occurrence, ["Encryption"])]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local cmkKeyId = baselineComponentIds["Encryption"]]

    [#assign componentState =
        {
            "Resources" : {
                "stream" : {
                    "Id" : streamId,
                    "Name" : core.FullName,
                    "Type" : AWS_KINESIS_DATA_STREAM_RESOURCE_TYPE,
                    "Monitored" : true
                }
            },
            "Attributes" : {
                "STREAM_NAME" : getExistingReference(streamId),
                "STREAM_ARN" : getArn(streamId)
            },
            "Roles" : {
                "Outbound" : {
                    "default" : "consume",
                    "consume" : kinesisDataStreamConsumePermssion(streamId) +
                                solution.Encryption.Enabled?then(
                                    kinesisStreamEncryptionStatement(
                                        [
                                            "kms:Decrypt"
                                        ],
                                        cmkKeyId,
                                        streamId
                                        ),
                                        []
                                ),
                    "produce" : kinesisDataStreamProducePermssion(streamId) +
                                solution.Encryption.Enabled?then(
                                    kinesisStreamEncryptionStatement(
                                        [
                                            "kms:GenerateDataKey"
                                        ],
                                        cmkKeyId,
                                        streamId
                                        ),
                                        []
                                )
                },
                "Inbound" : {
                }
            }
        }
    ]
[/#macro]
