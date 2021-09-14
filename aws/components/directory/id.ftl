[#ftl]
[@addResourceGroupInformation
    type=DIRECTORY_COMPONENT_TYPE
    attributes=[
        {
            "Names" : "aws:EnableSSO",
            "Types" : BOOLEAN_TYPE,
            "Default" : false
        }
    ]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE,
            AWS_DIRECTORY_SERVICE,
            AWS_SECRETS_MANAGER_SERVICE
        ]
/]
