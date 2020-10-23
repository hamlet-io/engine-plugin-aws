[#ftl]

[#-- Service Mapping --]
[@addDiagramServiceMapping
    provider=AWS_PROVIDER
    service=AWS_KINESIS_SERVICE
    diagramsClass="diagrams.aws.analytics.Kinesis"
/]

[@addDiagramResourceMapping
    provider=AWS_PROVIDER
    service=AWS_KINESIS_SERVICE
    resourceType=AWS_KINESIS_FIREHOSE_STREAM_RESOURCE_TYPE
    diagramsClass="diagrams.aws.analytics.KinesisDataFirehose"
/]
