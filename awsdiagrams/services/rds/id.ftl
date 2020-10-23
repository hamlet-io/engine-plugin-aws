[#ftl]

[#-- Service Mapping --]
[@addDiagramServiceMapping
    provider=AWS_PROVIDER
    service=AWS_RELATIONAL_DATABASE_SERVICE
    diagramsClass="diagrams.aws.database.RDS"
/]

[@addDiagramResourceMapping
    provider=AWS_PROVIDER
    service=AWS_RELATIONAL_DATABASE_SERVICE
    resourceType=AWS_RDS_CLUSTER_RESOURCE_TYPE
    diagramsClass="diagrams.aws.database.Aurora"
/]
