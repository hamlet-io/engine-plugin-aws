[#ftl]

[#-- Resources --]
[#assign AWS_KINESIS_FIREHOSE_STREAM_RESOURCE_TYPE = "firehosestream" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_KINESIS_SERVICE
    resource=AWS_KINESIS_FIREHOSE_STREAM_RESOURCE_TYPE
/]
