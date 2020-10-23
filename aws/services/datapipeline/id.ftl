[#ftl]

[#-- Resources --]
[#assign AWS_DATA_PIPELINE_RESOURCE_TYPE = "datapipeline"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_DATA_PIPELINE_SERVICE
    resource=AWS_DATA_PIPELINE_RESOURCE_TYPE
/]
