[#ftl]

[#macro aws_externalnetwork_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#assign componentState =
        {
            "Resources" : {
                "externalNetwork" : {
                    "Id" : formatResourceId(SHARED_EXTERNALNETWORK_RESOURCE_TYPE, core.Id ),
                    "Deployed" : true,
                    "Type" : SHARED_EXTERNALNETWORK_RESOURCE_TYPE
                }
            },
            "Attributes" : {
            },
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]
[/#macro]


[#macro aws_externalnetworkconnection_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local engine = solution.Engine ]

    [#local resources = {} ]

    [#switch engine ]
        [#case "SiteToSite"]

            [#local resources = mergeObjects( resources,
                {
                    "vpnConnection" : {
                        "Id" : formatResourceId(
                                    AWS_VPNGATEWAY_VPN_CONNECTION_RESOURCE_TYPE,
                                    core.Id
                        ),
                        "Type" : AWS_VPNGATEWAY_VPN_CONNECTION_RESOURCE_TYPE
                    },
                    "customerGateway" : {
                        "Id" : formatResourceId(
                                AWS_VPNGATEWAY_CUSTOMER_GATEWAY_RESOURCE_TYPE,
                                core.Id
                        ),
                        "Name" : core.FullName,
                        "Type" : AWS_VPNGATEWAY_CUSTOMER_GATEWAY_RESOURCE_TYPE
                    }
                }
            )]
            [/#list]
            [#break]
    [/#switch]

    [#assign componentState =
        {
            "Resources" : resources,
            "Attributes" : {
            },
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]
[/#macro]
