[#ftl]

[#-- Resources --]
[#assign AWS_CLIENTVPN_ENDPOINT_RESOURCE_TYPE = "clientvpnendpoint" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_CLIENTVPN_SERVICE
    resource=AWS_CLIENTVPN_ENDPOINT_RESOURCE_TYPE
/]

[#assign AWS_CLIENTVPN_AUTHORIZATION_RULE_RESOURCE_TYPE = "clientvpnauthorizationrule" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_CLIENTVPN_SERVICE
    resource=AWS_CLIENTVPN_AUTHORIZATION_RULE_RESOURCE_TYPE
/]

[#assign AWS_CLIENTVPN_ROUTE_RESOURCE_TYPE = "clientvpnroute" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_CLIENTVPN_SERVICE
    resource=AWS_CLIENTVPN_ROUTE_RESOURCE_TYPE
/]

[#assign AWS_CLIENTVPN_NETWORK_ASSOCIATION_RESOURCE_TYPE = "clientvpntargetnetworkassoc" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_CLIENTVPN_SERVICE
    resource=AWS_CLIENTVPN_NETWORK_ASSOCIATION_RESOURCE_TYPE
/]
