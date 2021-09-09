[#ftl]
[@addResourceGroupInformation
    type=DIRECTORY_COMPONENT_TYPE
    attributes=[]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE,
            AWS_DIRECTORY_SERVICE,
            AWS_SECRETS_MANAGER_SERVICE
        ]
/]

[@addResourceGroupAttributeValues
    type=DIRECTORY_COMPONENT_TYPE
    provider=AWS_PROVIDER
    extensions=[
        {
            "Names" : "Engine",
            "Values" : [ "ms-std", "ms-ent" ]
        }
    ]
/]
