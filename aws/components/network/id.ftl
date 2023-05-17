[#ftl]
[@addResourceGroupInformation
    type=NETWORK_COMPONENT_TYPE
    attributes=[]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_CLOUDWATCH_SERVICE,
            AWS_IDENTITY_SERVICE,
            AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE,
            AWS_ROUTE53RESOLVER_SERVICE
        ]
/]

[@addResourceGroupInformation
    type=NETWORK_ACL_COMPONENT_TYPE
    attributes=[]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
        ]
/]

[@addResourceGroupAttributeValues
    type=NETWORK_ACL_COMPONENT_TYPE
    provider=AWS_PROVIDER
    extensions=[
        {
            "Names": "DefaultACL",
            "Description" : "Apply the rules for this ACL to the default VPC ACL",
            "Types" : BOOLEAN_TYPE,
            "Default": false
        }
    ]
/]


[@addResourceGroupInformation
    type=NETWORK_ROUTE_TABLE_COMPONENT_TYPE
    attributes=[]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
        ]
/]


[#function getSubnets tier networkResources zoneFilter="" asReferences=true includeZone=false]
    [#local result = [] ]
    [#list networkResources.subnets[tier.Id] as zone, resources]

        [#local subnetId = resources["subnet"].Id ]

        [#local subnetId = asReferences?then(
                                getReference(subnetId),
                                subnetId)]

        [#if (zoneFilter?has_content && zoneFilter == zone) || !zoneFilter?has_content ]
            [#local result +=
                [
                    includeZone?then(
                        {
                            "subnetId" : subnetId,
                            "zone" : zone
                        },
                        subnetId
                    )
                ]
            ]
        [/#if]
    [/#list]
    [#return result]
[/#function]
