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
                "Inbound" : {
                    "networkacl" : {
                        "IPAddressGroups" : solution.IPAddressGroups,
                        "Description" : core.FullName
                    }
                },
                "Outbound" : {
                    "networkacl" : {
                        "Ports" : solution.Ports,
                        "IPAddressGroups" : solution.IPAddressGroups,
                        "Description" : core.FullName
                    }
                }
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

            [#list solution.Links as id,link]
                [#if link?is_hash]

                    [#local linkTarget = getLinkTarget(occurrence, link) ]

                    [@debug message="Link Target" context=linkTarget enabled=false /]

                    [#if !linkTarget?has_content]
                        [#continue]
                    [/#if]

                    [#local linkTargetCore = linkTarget.Core ]
                    [#local linkTargetConfiguration = linkTarget.Configuration ]
                    [#local linkTargetResources = linkTarget.State.Resources ]
                    [#local linkTargetAttributes = linkTarget.State.Attributes ]

                    [#switch linkTargetCore.Type]
                        [#case NETWORK_ROUTER_COMPONENT_TYPE ]

                            [#switch solution.Engine ]
                                [#case "SiteToSite" ]

                                    [#local resources += {
                                        "VpnConnections" : {
                                            id : {
                                                "Id" : formatResourceId(
                                                    AWS_VPNGATEWAY_VPN_CONNECTION_RESOURCE_TYPE,
                                                    core.Id,
                                                    linkTarget.Core.Id
                                                ),
                                                "Name" : formatName(core.FullName, linkTargetCore.Name),
                                                "Type" : AWS_VPNGATEWAY_VPN_CONNECTION_RESOURCE_TYPE
                                            }
                                        }
                                    }]
                                    [#break]
                            [/#switch]
                            [#break]
                    [/#switch]
                [/#if]
            [/#list]


            [#local resources = mergeObjects( resources,
                {
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
