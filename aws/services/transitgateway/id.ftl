[#ftl]

[#-- Resources --]
[#assign AWS_TRANSITGATEWAY_GATEWAY_RESOURCE_TYPE = "transitGateway" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_TRANSIT_GATEWAY_SERVICE
    resource=AWS_TRANSITGATEWAY_GATEWAY_RESOURCE_TYPE
/]
[#assign AWS_TRANSITGATEWAY_ATTACHMENT_RESOURCE_TYPE = "transitGatewayAttachment" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_TRANSIT_GATEWAY_SERVICE
    resource=AWS_TRANSITGATEWAY_ATTACHMENT_RESOURCE_TYPE
/]
[#assign AWS_TRANSITGATEWAY_ROUTE_RESOURCE_TYPE = "transitGatewayRoute" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_TRANSIT_GATEWAY_SERVICE
    resource=AWS_TRANSITGATEWAY_ROUTE_RESOURCE_TYPE
/]

[#assign AWS_TRANSITGATEWAY_ROUTETABLE_RESOURCE_TYPE = "transitGatewayRouteTable" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_TRANSIT_GATEWAY_SERVICE
    resource=AWS_TRANSITGATEWAY_ROUTETABLE_RESOURCE_TYPE
/]
[#assign AWS_TRANSITGATEWAY_ROUTETABLE_ASSOCIATION_TYPE = "transitGatewayRouteTableAssociation" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_TRANSIT_GATEWAY_SERVICE
    resource=AWS_TRANSITGATEWAY_ROUTETABLE_ASSOCIATION_TYPE
/]
[#assign AWS_TRANSITGATEWAY_ROUTETABLE_PROPOGATION_TYPE = "transitGatewayRouteTablePropogation" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_TRANSIT_GATEWAY_SERVICE
    resource=AWS_TRANSITGATEWAY_ROUTETABLE_PROPOGATION_TYPE
/]
