[#ftl]

[#-- Resources --]
[#assign AWS_NETWORK_FIREWALL_RESOURCE_TYPE = "networkfirewall" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_NETWORK_FIREWALL_SERVICE
    resource=AWS_NETWORK_FIREWALL_RESOURCE_TYPE
/]


[#assign AWS_NETWORK_FIREWALL_POLICY_RESOURCE_TYPE = "networkfirewallpolicy" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_NETWORK_FIREWALL_SERVICE
    resource=AWS_NETWORK_FIREWALL_POLICY_RESOURCE_TYPE
/]

[#assign AWS_NETWORK_FIREWALL_LOGGING_RESOURCE_TYPE = "networkfirewalllogging" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_NETWORK_FIREWALL_SERVICE
    resource=AWS_NETWORK_FIREWALL_LOGGING_RESOURCE_TYPE
/]

[#assign AWS_NETWORK_FIREWALL_RULEGROUP_RESOURCE_TYPE = "networkfirewallrulegroup" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_NETWORK_FIREWALL_SERVICE
    resource=AWS_NETWORK_FIREWALL_RULEGROUP_RESOURCE_TYPE
/]
