[#ftl]

[#macro aws_externalnetwork_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local networkCIDRs = getGroupCIDRs(solution.IPAddressGroups, true, occurrence)]

    [#assign componentState =
        {
            "Resources" : {},
            "Attributes" : {
                "NETWORK_ADDRESSES" : networkCIDRs?join(",")
            } +
            attributeIfTrue(
                "BGP_ASN",
                solution.BGP.Enabled,
                solution.BGP.ASN
            ),
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]
[/#macro]


[#macro aws_externalnetworkconnection_cf_state occurrence parent={} ]

    [#local parentAttributes = parent.State.Attributes]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local engine = solution.Engine ]

    [#local resources = {} ]

    [#switch engine ]
        [#case "SiteToSite"]

            [#local customerGatewayId = formatResourceId(
                                            AWS_VPNGATEWAY_CUSTOMER_GATEWAY_RESOURCE_TYPE,
                                            core.Id)]
            [#local resources = mergeObjects( resources,
                {
                    "vpnConnection" : {
                        "Id" : formatResourceId(
                                    AWS_VPNGATEWAY_VPN_CONNECTION_RESOURCE_TYPE,
                                    core.Id
                        ),
                        "Name" : core.FullName,
                        "Type" : AWS_VPNGATEWAY_VPN_CONNECTION_RESOURCE_TYPE
                    },
                    "customerGateway" : {
                        "Id" : customerGatewayId,
                        "Name" : core.FullName,
                        "Type" : AWS_VPNGATEWAY_CUSTOMER_GATEWAY_RESOURCE_TYPE
                    }
                }
            )]
            [#break]
    [/#switch]

    [#assign componentState =
        {
            "Resources" : resources,
            "Attributes" : {
            } +
            parentAttributes +
            attributeIfTrue(
                "CUSTOMER_GATEWAY_ID",
                ( engine == "SiteToSite" ),
                getExistingReference(customerGatewayId)
            ),
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]
[/#macro]
