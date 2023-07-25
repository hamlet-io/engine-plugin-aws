[#ftl]

[#-- Resources --]
[#assign AWS_ES_RESOURCE_TYPE = "es" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTICSEARCH_SERVICE
    resource=AWS_ES_RESOURCE_TYPE
/]
