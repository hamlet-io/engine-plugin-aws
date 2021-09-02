[#ftl]

[#-- Resources --]
[#assign AWS_VPC_RESOURCE_TYPE = "vpc" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
    resource=AWS_VPC_RESOURCE_TYPE
/]

[#assign AWS_VPC_SUBNET_RESOURCE_TYPE = "subnet" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
    resource=AWS_VPC_SUBNET_RESOURCE_TYPE
/]

[#assign AWS_VPC_FLOWLOG_RESOURCE_TYPE = "vpcflowlogs" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
    resource=AWS_VPC_FLOWLOG_RESOURCE_TYPE
/]


[#assign AWS_VPC_ROUTE_TABLE_RESOURCE_TYPE = "routeTable" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
    resource=AWS_VPC_ROUTE_TABLE_RESOURCE_TYPE
/]

[#assign AWS_VPC_ROUTE_RESOURCE_TYPE = "route" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
    resource=AWS_VPC_ROUTE_RESOURCE_TYPE
/]
[#assign AWS_VPC_NETWORK_ROUTE_TABLE_ASSOCIATION_TYPE = "association" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
    resource=AWS_VPC_NETWORK_ROUTE_TABLE_ASSOCIATION_TYPE
/]
[#assign AWS_VPC_NETWORK_ROUTE_TABLE_GATEWAY_ASSOCIATION_TYPE = "gatewayrouteassociation" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
    resource=AWS_VPC_NETWORK_ROUTE_TABLE_GATEWAY_ASSOCIATION_TYPE
/]

[#assign AWS_VPC_NETWORK_ACL_RESOURCE_TYPE = "networkACL" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
    resource=AWS_VPC_NETWORK_ACL_RESOURCE_TYPE
/]
[#assign AWS_VPC_NETWORK_ACL_RULE_RESOURCE_TYPE = "rule"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
    resource=AWS_VPC_NETWORK_ACL_RULE_RESOURCE_TYPE
/]
[#assign AWS_VPC_NETWORK_ACL_ASSOCIATION_TYPE = "association" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
    resource=AWS_VPC_NETWORK_ACL_ASSOCIATION_TYPE
/]

[#assign AWS_VPC_SUBNET_TYPE = "subnet"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
    resource=AWS_VPC_SUBNET_TYPE
/]

[#assign AWS_VPC_SUBNETLIST_TYPE = "subnetList" ]

[#assign AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE = "securityGroup" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
    resource=AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE
/]
[#assign AWS_VPC_SECURITY_GROUP_INGRESS_RESOURCE_TYPE = "securityGroupIngress" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
    resource=AWS_VPC_SECURITY_GROUP_INGRESS_RESOURCE_TYPE
/]
[#assign AWS_VPC_SECURITY_GROUP_EGRESS_RESOURCE_TYPE = "securityGroupEgress" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
    resource=AWS_VPC_SECURITY_GROUP_EGRESS_RESOURCE_TYPE
/]

[#assign AWS_VPC_IGW_RESOURCE_TYPE = "igw" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
    resource=AWS_VPC_IGW_RESOURCE_TYPE
/]
[#assign AWS_VPC_IGW_ATTACHMENT_TYPE = "igwXattachment" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
    resource=AWS_VPC_IGW_ATTACHMENT_TYPE
/]
[#assign AWS_VPC_NAT_GATEWAY_RESOURCE_TYPE = "natGateway" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
    resource=AWS_VPC_NAT_GATEWAY_RESOURCE_TYPE
/]

[#assign AWS_VPC_VPCENDPOINT_RESOURCE_TYPE = "vpcEndPoint"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
    resource=AWS_VPC_VPCENDPOINT_RESOURCE_TYPE
/]
[#assign AWS_VPC_ENDPOINT_RESOURCE_TYPE = "endpointGateway" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
    resource=AWS_VPC_ENDPOINT_RESOURCE_TYPE
/]

[#assign AWS_VPC_ENDPOINT_SERVICE_RESOURCE_TYPE = "vpcEndPointSerivce" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
    resource=AWS_VPC_ENDPOINT_SERVICE_RESOURCE_TYPE
/]
[#assign AWS_VPC_ENDPOINT_SERVICE_PERMISSION_RESOURCE_TYPE = "vpcEndPointServicePermission" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
    resource=AWS_VPC_ENDPOINT_SERVICE_PERMISSION_RESOURCE_TYPE
/]
[#assign AWS_VPC_ENDPOINT_SERVICE_NOTIFICATION_RESOURCE_TYPE = "vpcEndpontServiceNotification" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
    resource=AWS_VPC_ENDPOINT_SERVICE_NOTIFICATION_RESOURCE_TYPE
/]

[#function formatSecurityGroupId ids...]
    [#return formatResourceId(
                AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE,
                ids)]
[/#function]

[#function formatDependentSecurityGroupId resourceId extensions...]
    [#return formatDependentResourceId(
                AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE,
                resourceId,
                extensions)]
[/#function]

[#-- Where possible, the dependent resource variant should be used --]
[#-- based on the resource id of the component using the security  --]
[#-- group. This avoids clashes where components has the same id   --]
[#-- but different types                                           --]
[#function formatComponentSecurityGroupId tier component extensions...]
    [#return formatComponentResourceId(
                AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE,
                tier,
                component,
                extensions)]
[/#function]

[#function formatDependentComponentSecurityGroupId
            tier
            component
            resourceId
            extensions...]
    [#return
        migrateToResourceId(
            formatDependentSecurityGroupId(resourceId, extensions),
            formatComponentSecurityGroupId(tier, component, extensions)
        )]
[/#function]

[#-- Use the associated security group where possible as the dependent --]
[#-- resource. (It may well in turn be a dependent resource)           --]
[#-- As nothing depends in ingress resources, Cloud Formation will     --]
[#-- deal with deleting the resource with the old format id.           --]
[#function formatDependentSecurityGroupIngressId resourceId extensions...]
    [#return formatDependentResourceId(
                "ingress",
                resourceId,
                extensions)]
[/#function]

[#function formatDependentSecurityGroupEgressId resourceId extensions...]
    [#return formatDependentResourceId(
                AWS_VPC_SECURITY_GROUP_EGRESS_RESOURCE_TYPE,
                resourceId,
                extensions)]
[/#function]

[#function formatComponentSecurityGroupIngressId tier component extensions...]
    [#return formatComponentResourceId(
                AWS_VPC_SECURITY_GROUP_INGRESS_RESOURCE_TYPE,
                tier,
                component,
                extensions)]
[/#function]

[#function formatSSHFromProxySecurityGroupId ]
    [#return
        migrateToResourceId(
            formatComponentSecurityGroupId("all", "ssh"),
            formatComponentSecurityGroupId("mgmt", "nat")
        )]
[/#function]

[#function formatVPCId]
    [#return
        migrateToResourceId(
            formatSegmentResourceId(AWS_VPC_RESOURCE_TYPE),
            formatSegmentResourceId(AWS_VPC_RESOURCE_TYPE, AWS_VPC_RESOURCE_TYPE)
        )]
[/#function]

[#function formatVPCIGWId]
    [#return
        migrateToResourceId(
            formatSegmentResourceId(AWS_VPC_IGW_RESOURCE_TYPE),
            formatSegmentResourceId(AWS_VPC_IGW_RESOURCE_TYPE, AWS_VPC_IGW_RESOURCE_TYPE)
        )]
[/#function]

[#function formatVPCTemplateId]
    [#return
        getExistingReference(
            formatSegmentResourceId(AWS_VPC_RESOURCE_TYPE, AWS_VPC_RESOURCE_TYPE))?has_content?then(
                AWS_VPC_RESOURCE_TYPE,
                formatSegmentResourceId(AWS_VPC_RESOURCE_TYPE)
            )]
[/#function]

[#function formatVPCIGWTemplateId]
    [#return
        getExistingReference(
            formatSegmentResourceId(AWS_VPC_IGW_RESOURCE_TYPE, AWS_VPC_IGW_RESOURCE_TYPE))?has_content?then(
                AWS_VPC_IGW_RESOURCE_TYPE,
                formatSegmentResourceId(AWS_VPC_IGW_RESOURCE_TYPE)
            )]
[/#function]

[#function formatVPCFlowLogsId extensions...]
    [#return formatDependentResourceId(
        AWS_VPC_FLOWLOG_RESOURCE_TYPE,
        formatSegmentResourceId(AWS_VPC_RESOURCE_TYPE),
        extensions)]
[/#function]

[#function formatSubnetId tier zone]
    [#return formatZoneResourceId(
            AWS_VPC_SUBNET_TYPE,
            tier,
            zone)]
[/#function]

[#function formatRouteTableAssociationId subnetId extensions...]
    [#return formatDependentResourceId(
            AWS_VPC_NETWORK_ROUTE_TABLE_ASSOCIATION_TYPE,
            subnetId,
            AWS_VPC_ROUTE_TABLE_RESOURCE_TYPE,
            extensions)]
[/#function]

[#function formatNetworkACLAssociationId subnetId extensions...]
    [#return formatDependentResourceId(
            AWS_VPC_NETWORK_ACL_ASSOCIATION_TYPE,
            subnetId,
            AWS_VPC_NETWORK_ACL_RESOURCE_TYPE,
            extensions)]
[/#function]

[#function formatRouteTableId ids...]
    [#return formatResourceId(
            AWS_VPC_ROUTE_TABLE_RESOURCE_TYPE,
            ids)]
[/#function]

[#function formatRouteId routeTableId extensions...]
    [#return formatDependentResourceId(
            AWS_VPC_ROUTE_RESOURCE_TYPE,
            routeTableId,
            extensions)]
[/#function]

[#function formatNetworkACLId ids...]
    [#return formatResourceId(
            AWS_VPC_NETWORK_ACL_RESOURCE_TYPE,
            ids)]
[/#function]

[#function formatNetworkACLEntryId networkACLId outbound extensions...]
    [#return formatDependentResourceId(
            "rule",
            networkACLId,
            outbound?then("out","in"),
            extensions)]
[/#function]

[#function formatNATGatewayId tier zone]
    [#return formatZoneResourceId(
            AWS_VPC_NAT_GATEWAY_RESOURCE_TYPE,
            tier,
            zone)]
[/#function]

[#function formatVPCEndPointId service extensions...]
    [#return formatSegmentResourceId(
        AWS_VPC_VPCENDPOINT_RESOURCE_TYPE,
        service,
        extensions)]
[/#function]
