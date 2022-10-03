[#ftl]

[#-- Resources --]
[#assign AWS_GLUE_DATABASE_RESOURCE_TYPE = "gluedatabase" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_GLUE_SERVICE
    resource=AWS_GLUE_DATABASE_RESOURCE_TYPE
/]

[#assign AWS_GLUE_TABLE_RESOURCE_TYPE = "gluetable" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_GLUE_SERVICE
    resource=AWS_GLUE_TABLE_RESOURCE_TYPE
/]

[#assign AWS_GLUE_CRAWLER_RESOURCE_TYPE = "gluecrawler" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_GLUE_SERVICE
    resource=AWS_GLUE_CRAWLER_RESOURCE_TYPE
/]

[#assign AWS_GLUE_CONNECTION_RESOURCE_TYPE = "glueconnection" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_GLUE_SERVICE
    resource=AWS_GLUE_CONNECTION_RESOURCE_TYPE
/]
