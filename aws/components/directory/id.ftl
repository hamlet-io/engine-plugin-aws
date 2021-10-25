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

[@addResourceGroupAttributeValues
    type=DIRECTORY_COMPONENT_TYPE
    provider=AWS_PROVIDER
    extensions=[
        {
            "Names" : "Engine",
            "Values" : [
                "shared:Simple",
                "shared:ActiveDirectory",
                "ADConnector"
            ]
        },
        {
            "Names" : "engine:ADConnector",
            "Children" : [
                {
                    "Names" : "ADIPAddresses",
                    "Description" : "The IP addresses of the DNS servers for the AD Domain controllers",
                    "Types" : ARRAY_OF_STRING_TYPE,
                    "Default" : []
                }
            ]
        }
    ]
/]
