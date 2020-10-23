[#ftl]

[#-- Service Mapping --]
[@addDiagramServiceMapping
    provider=AWS_PROVIDER
    service=AWS_DYNAMODB_SERVICE
    diagramsClass="diagrams.aws.database.Dynamodb"
/]

[@addDiagramResourceMapping
    provider=AWS_PROVIDER
    service=AWS_DYNAMODB_SERVICE
    resourceType=AWS_DYNAMODB_TABLE_RESOURCE_TYPE
    diagramsClass="diagrams.aws.database.DynamodbTable"
/]
