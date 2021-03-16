[#ftl]

[#-- Resources --]
[#assign AWS_VPNGATEWAY_CUSTOMER_GATEWAY_RESOURCE_TYPE = "vpnCustomerGateway" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VPN_GATEWAY_SERVICE
    resource=AWS_VPNGATEWAY_CUSTOMER_GATEWAY_RESOURCE_TYPE
/]

[#assign AWS_VPNGATEWAY_VIRTUAL_GATEWAY_RESOURCE_TYPE = "vpnVirtualGateway" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VPN_GATEWAY_SERVICE
    resource=AWS_VPNGATEWAY_VIRTUAL_GATEWAY_RESOURCE_TYPE
/]
[#assign AWS_VPNGATEWAY_VIRTUAL_GATEWAY_ATTACHMENT_RESOURCE_TYPE = "vpnVirtualGatewayAttachment" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VPN_GATEWAY_SERVICE
    resource=AWS_VPNGATEWAY_VIRTUAL_GATEWAY_ATTACHMENT_RESOURCE_TYPE
/]
[#assign AWS_VPNGATEWAY_VIRTUAL_GATEWAY_PROPOGATION_RESOURCE_TYPE = "vpnVirtualGatewayPropogation" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VPN_GATEWAY_SERVICE
    resource=AWS_VPNGATEWAY_VIRTUAL_GATEWAY_PROPOGATION_RESOURCE_TYPE
/]
[#assign AWS_VPNGATEWAY_VPN_CONNECTION_RESOURCE_TYPE = "vpnConnection" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VPN_GATEWAY_SERVICE
    resource=AWS_VPNGATEWAY_VPN_CONNECTION_RESOURCE_TYPE
/]
[#assign AWS_VPNGATEWAY_VPN_CONNECTION_ROUTE_RESOURCE_TYPE = "vpnConnectionRoute" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VPN_GATEWAY_SERVICE
    resource=AWS_VPNGATEWAY_VPN_CONNECTION_ROUTE_RESOURCE_TYPE
/]
[#assign AWS_VPNGATEWAY_VPN_CONNECTION_TUNNEL_RESOURCE_TYPE = "vpnConnectionTunnel" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_VPN_GATEWAY_SERVICE
    resource=AWS_VPNGATEWAY_VPN_CONNECTION_TUNNEL_RESOURCE_TYPE
/]
