[#ftl]

[#macro aws_router_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local routerId = formatResourceId(AWS_TRANSITGATEWAY_GATEWAY_RESOURCE_TYPE, core.Id) ]
    [#local routeTableId = formatResourceId(AWS_TRANSITGATEWAY_ROUTETABLE_RESOURCE_TYPE, core.Id) ]

    [#assign componentState =
        {
            "Resources" : {
                "transitGateway" : {
                    "Id" : routerId,
                    "Name" : core.FullName,
                    "Type" : AWS_TRANSITGATEWAY_GATEWAY_RESOURCE_TYPE
                },
                "routeTable" : {
                    "Id" : routeTableId,
                    "Name" : core.FullName,
                    "Type" : AWS_TRANSITGATEWAY_ROUTETABLE_RESOURCE_TYPE
                }
            } +
            attributeIfTrue(
                "resourceShare",
                solution["aws:ResourceSharing"].Enabled,
                {
                    "Id" : formatResourceId(AWS_RESOURCEACCESS_SHARE_RESOURCE_TYPE, core.Id),
                    "Name" : core.FullName,
                    "Type" : AWS_RESOURCEACCESS_SHARE_RESOURCE_TYPE
                }
            ),
            "Attributes" : {
            },
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]
[/#macro]


[#macro aws_routerstaticroute_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local resources = {}]

    [#local destinationCidrs = getGroupCIDRs(solution.IPAddressGroups, true, occurrence)]

    [#switch solution.Action]
        [#case "forward" ]
            [#local links = getLinkTargets(occurrence, solution.Links) ]
            [#list links as id,link ]
                [#switch link.Core.Type ]
                    [#case EXTERNALSERVICE_COMPONENT_TYPE ]
                        [#local resources = mergeObjects(resources,
                                        {
                                            "routeAssociations" : {
                                                link.Core.Id : {
                                                    "Id" : formatResourceId(
                                                        AWS_TRANSITGATEWAY_ROUTETABLE_ASSOCIATION_TYPE,
                                                        core.Id,
                                                        link.Core.Id
                                                    ),
                                                    "Type" : AWS_TRANSITGATEWAY_ROUTETABLE_ASSOCIATION_TYPE
                                                }
                                            }
                                        })]

                    [#case NETWORK_GATEWAY_COMPONENT_TYPE ]
                        [#list destinationCidrs as destinationCidr ]
                            [#local destinationCidrId = replaceAlphaNumericOnly(destinationCidr)]
                            [#local resources = mergeObjects(resources,
                                            {
                                                "routes" : {
                                                    link.Core.Id : {
                                                        destinationCidrId : {
                                                            "Id" : formatResourceId(
                                                                AWS_TRANSITGATEWAY_ROUTE_RESOURCE_TYPE,
                                                                core.Id,
                                                                link.Core.Id,
                                                                destinationCidrId
                                                            ),
                                                            "Type" : AWS_TRANSITGATEWAY_ROUTE_RESOURCE_TYPE
                                                        }
                                                    }
                                                }
                                            })]
                        [/#list]
                        [#break]
                [/#switch]
            [/#list]
            [#break]

        [#case "blackhole" ]
            [#list destinationCidrs as destinationCidr ]
                [#local destinationCidrId = replaceAlphaNumericOnly(destinationCidr)]
                [#local resources = mergeObjects(resources,
                                {
                                    "routes" : {
                                        destinationCidrId : {
                                            "Id" : formatResourceId(
                                                AWS_TRANSITGATEWAY_ROUTE_RESOURCE_TYPE,
                                                core.Id,
                                                destinationCidrId
                                            ),
                                            "Type" : AWS_TRANSITGATEWAY_ROUTE_RESOURCE_TYPE
                                        }
                                    }
                                })]
            [/#list]
            [#break]

    [/#switch]

    [#assign componentState =
        {
            "Resources" : resources,
            "Attributes" : {},
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]
[/#macro]
