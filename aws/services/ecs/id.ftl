[#ftl]

[#-- Resources --]
[#assign AWS_ECS_RESOURCE_TYPE = "ecs" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_CONTAINER_SERVICE
    resource=AWS_ECS_RESOURCE_TYPE
/]
[#assign AWS_ECS_TASK_RESOURCE_TYPE = "ecsTask"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_CONTAINER_SERVICE
    resource=AWS_ECS_TASK_RESOURCE_TYPE
/]
[#assign AWS_ECS_SERVICE_RESOURCE_TYPE = "ecsService"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_CONTAINER_SERVICE
    resource=AWS_ECS_SERVICE_RESOURCE_TYPE
/]
[#assign AWS_ECS_CAPACITY_PROVIDER_RESOURCE_TYPE = "ecsCapacityProvider" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_CONTAINER_SERVICE
    resource=AWS_ECS_CAPACITY_PROVIDER_RESOURCE_TYPE
/]

[#assign AWS_ECS_CAPACITY_PROVIDER_ASSOCIATION_RESOURCE_TYPE = "ecsCapacityProviderAssoc" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_CONTAINER_SERVICE
    resource=AWS_ECS_CAPACITY_PROVIDER_ASSOCIATION_RESOURCE_TYPE
/]
