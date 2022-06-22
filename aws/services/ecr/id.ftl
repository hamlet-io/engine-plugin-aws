[#ftl]

[#-- Resources --]
[#assign AWS_ECR_REPOSITORY_RESOURCE_TYPE = "ecrrepository" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_CONTAINER_REGISTRY_SERVICE
    resource=AWS_ECR_REPOSITORY_RESOURCE_TYPE
/]
