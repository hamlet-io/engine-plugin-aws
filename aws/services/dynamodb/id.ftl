[#ftl]

[#-- Resources --]
[#assign AWS_DYNAMODB_TABLE_RESOURCE_TYPE = "dynamoTable" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_DYNAMODB_SERVICE
    resource=AWS_DYNAMODB_TABLE_RESOURCE_TYPE
/]

[#assign AWS_DYNAMODB_ITEM_RESOURCE_TYPE = "dyanmoItem" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_DYNAMODB_SERVICE
    resource=AWS_DYNAMODB_ITEM_RESOURCE_TYPE
/]
