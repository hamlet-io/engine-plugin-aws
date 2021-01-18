[#ftl]
[@addResourceGroupInformation
    type=NETWORK_ROUTER_COMPONENT_TYPE
    attributes=[
        {
            "Names": "ResourceSharing",
            "Description" : "Allows for the resource to be shared with other Accounts",
            "Children" : [
                {
                    "Names" : "Enabled",
                    "Types" : BOOLEAN_TYPE,
                    "Default" : false
                },
                {
                    "Names" : "AccountPrincipals",
                    "Description" : "List of AWS Account Ids or Organisation ARNS to share the resource with",
                    "Types": ARRAY_OF_STRING_TYPE,
                    "Default" : []
                },
                {
                    "Names" : "AllowExternalPrincipals",
                    "Description" : "Allow resources to be shared outside of the Organisation",
                    "Types" : BOOLEAN_TYPE,
                    "Default" : false
                }
            ]
        }
    ]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_TRANSIT_GATEWAY_SERVICE,
            AWS_RESOURCE_ACCESS_SERVICE
        ]
/]

[@addResourceGroupInformation
    type=NETWORK_ROUTER_STATIC_ROUTE_COMPONENT_TYPE
    attributes=[]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_TRANSIT_GATEWAY_SERVICE
        ]
/]
