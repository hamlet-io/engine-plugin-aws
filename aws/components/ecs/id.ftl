[#ftl]
[@addResourceGroupInformation
    type=ECS_COMPONENT_TYPE
    attributes=[]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_CLOUDWATCH_SERVICE,
            AWS_ELASTIC_COMPUTE_SERVICE,
            AWS_ELASTIC_CONTAINER_SERVICE,
            AWS_IDENTITY_SERVICE,
            AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE,
            AWS_AUTOSCALING_SERVICE,
            AWS_KEY_MANAGEMENT_SERVICE,
            AWS_SYSTEMS_MANAGER_SERVICE
        ]
/]

[@addResourceGroupInformation
    type=ECS_SERVICE_COMPONENT_TYPE
    attributes=[
        {
            "Names" : "FargatePlatform",
            "Description" : "The version of the fargate platform to use",
            "Types" : STRING_TYPE,
            "Default" : "LATEST"
        }
    ]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=[]
/]

[@addResourceGroupInformation
    type=ECS_TASK_COMPONENT_TYPE
    attributes=[
        {
            "Names" : "FargatePlatform",
            "Description" : "The version of the fargate platform to use",
            "Types" : STRING_TYPE,
            "Default" : "LATEST"
        }
    ]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=[]
/]
