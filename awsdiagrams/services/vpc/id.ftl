[#ftl]

[#-- Service Mapping --]
[@addDiagramServiceMapping
    provider=AWS_PROVIDER
    service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
    diagramsClass="diagrams.aws.network.VPC"
/]

[#-- Resource Mappings --]
[@addDiagramResourceMapping
    provider=AWS_PROVIDER
    service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
    resourceType=AWS_VPC_NAT_GATEWAY_RESOURCE_TYPE
    diagramsClass="diagrams.aws.network.NATGateway"
/]

[#list [ AWS_VPC_IGW_ATTACHMENT_TYPE, AWS_VPC_IGW_RESOURCE_TYPE ] as igwResource ]
    [@addDiagramResourceMapping
        provider=AWS_PROVIDER
        service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
        resourceType=igwResource
        diagramsClass="diagrams.aws.network.InternetGateway"
    /]
[/#list]

[#list [AWS_VPC_ROUTE_TABLE_RESOURCE_TYPE, AWS_VPC_ROUTE_RESOURCE_TYPE, AWS_VPC_NETWORK_ROUTE_TABLE_ASSOCIATION_TYPE ] as routeResource ]
    [@addDiagramResourceMapping
        provider=AWS_PROVIDER
        service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
        resourceType=routeResource
        diagramsClass="diagrams.aws.network.RouteTable"
    /]
[/#list]


[#list [AWS_VPC_VPCENDPOINT_RESOURCE_TYPE,  AWS_VPC_ENDPOINT_RESOURCE_TYPE ] as endpointResource ]
    [@addDiagramResourceMapping
        provider=AWS_PROVIDER
        service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
        resourceType=endpointResource
        diagramsClass="diagrams.aws.network.Endpoint"
    /]
[/#list]


[#list [AWS_VPC_NETWORK_ACL_RESOURCE_TYPE,  AWS_VPC_NETWORK_ACL_RULE_RESOURCE_TYPE, AWS_VPC_NETWORK_ACL_ASSOCIATION_TYPE ] as naclResource ]
    [@addDiagramResourceMapping
        provider=AWS_PROVIDER
        service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
        resourceType=naclResource
        diagramsClass="diagrams.aws.network.Nacl"
    /]
[/#list]

[#list [AWS_VPC_SUBNET_RESOURCE_TYPE,  AWS_VPC_SUBNET_TYPE ] as subnetResource ]
    [@addDiagramResourceMapping
        provider=AWS_PROVIDER
        service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
        resourceType=subnetResource
        diagramsClass="diagrams.aws.network.PrivateSubnet"
    /]
[/#list]

[#list [AWS_VPC_ENDPOINT_SERVICE_RESOURCE_TYPE,  AWS_VPC_ENDPOINT_SERVICE_PERMISSION_RESOURCE_TYPE, AWS_VPC_ENDPOINT_SERVICE_NOTIFICATION_RESOURCE_TYPE ] as subnetResource ]
    [@addDiagramResourceMapping
        provider=AWS_PROVIDER
        service=AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
        resourceType=subnetResource
        diagramsClass="diagrams.aws.network.Privatelink"
    /]
[/#list]
