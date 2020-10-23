[#ftl]

[#-- Resources --]
[#assign AWS_ES_RESOURCE_TYPE = "es" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTICSEARCH_SERVICE
    resource=AWS_ES_RESOURCE_TYPE
/]

[#function formatElasticSearchId tier component extensions...]
    [#return formatComponentResourceId(
                AWS_ES_RESOURCE_TYPE,
                tier,
                component,
                extensions)]
[/#function]
