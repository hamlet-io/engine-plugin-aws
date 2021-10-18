[#ftl]

[#macro aws_clientvpn_cf_state occurrence parent={} ]
    [#local core = getOccurrenceCore(occurrence) ]
    [#local solution = getOccurrenceSolution(occurrence) ]

    [#local certificateObject = getCertificateObject(solution.Certificate!"") ]

    [#local vpnClientId = formatResourceId(AWS_CLIENTVPN_ENDPOINT_RESOURCE_TYPE, core.Id)]
    [#local logGroupId = formatDependentLogGroupId(vpnClientId)]

    [#local loggingResources = {}]

    [#if solution.Logging ]
        [#local loggingResources = {
            "lg" : {
                "Id" : logGroupId,
                "Name" : core.FullAbsolutePath,
                "Type" : AWS_CLOUDWATCH_LOG_GROUP_RESOURCE_TYPE
            },
            "lgstream" : {
                "Id" : formatDependentResourceId(
                    AWS_CLOUDWATCH_LOG_GROUP_STREAM_RESOURCE_TYPE,
                    logGroupId
                ),
                "Name" : "ClientVPNConnections",
                "Type" : AWS_CLOUDWATCH_LOG_GROUP_STREAM_RESOURCE_TYPE
            }
        }]
    [/#if]

    [#local zoneResources = {}]

    [#list getZones() as zone ]
        [#local zoneResources = mergeObjects(
            zoneResources,
            {
                zone.Id : {
                    "networkassoc" : {
                        "Id" : formatResourceId(
                            AWS_CLIENTVPN_NETWORK_ASSOCIATION_RESOURCE_TYPE,
                            core.Id,
                            zone.Id
                        ),
                        "Name" : formatName(core.FullName, zone.Name),
                        "Type" : AWS_CLIENTVPN_NETWORK_ASSOCIATION_RESOURCE_TYPE
                    }
                }
            })]

        [#list getGroupCIDRs(solution.Network.Destinations.IPAddressGroups) as cidr ]
            [#local cidrId = replaceAlphaNumericOnly(cidr)]

            [#local zoneResources = mergeObjects(
                zoneResources,
                {
                    zone.Id : {
                        formatName("route", cidrId) : {
                            "Id" : formatResourceId(
                                AWS_CLIENTVPN_ROUTE_RESOURCE_TYPE,
                                core.Id,
                                zone.Id,
                                cidrId
                            ),
                            "Name" : formatName(core.FullName, cidrId),
                            "Type" : AWS_CLIENTVPN_ROUTE_RESOURCE_TYPE
                        }
                    }
                }
            )]
        [/#list]
    [/#list]

    [#local authorisationResources = {}]

    [#list solution.AuthorisationRules as id, authorisationRule]
        [#list getGroupCIDRs(authorisationRule.Destinations.IPAddressGroups)  as cidr ]
            [#local cidrId = replaceAlphaNumericOnly(cidr)]
            [#local authorisationResources += {
                id : {
                    cidrId : {
                        "rule" : {
                            "Id" : formatResourceId(
                                AWS_CLIENTVPN_AUTHORIZATION_RULE_RESOURCE_TYPE,
                                core.Id,
                                id
                            ),
                            "Name" : formatName(core.FullName, id),
                            "Type" : AWS_CLIENTVPN_AUTHORIZATION_RULE_RESOURCE_TYPE
                        }
                    }
                }
            }]
        [/#list]
    [/#list]

    [#assign componentState =
        {
            "Resources" : {
                "endpoint" : {
                    "Id" : formatResourceId(AWS_CLIENTVPN_ENDPOINT_RESOURCE_TYPE, core.Id),
                    "Name" : core.FullName,
                    "Type" : AWS_CLIENTVPN_ENDPOINT_RESOURCE_TYPE
                },
                "zoneResources" : zoneResources,
                "authorisationRules" : authorisationResources
            } +
            attributeIfContent("logging", loggingResources),
            "Attributes" : {
                "VPN_CLIENT_ID" : getExistingReference(vpnClientId)
            },
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]
[/#macro]
