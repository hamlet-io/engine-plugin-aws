[#ftl]

[#macro aws_network_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#-- Only apply legacy controls to the default master data vpc --]
    [#local legacyVpc = getLegacyVpc()
                            && core.Tier.Id == "mgmt" && core.Component.RawId == "vpc"
                            && core.Instance.Id == "" && core.Version.Id = ""]

    [#if legacyVpc ]
        [#local vpcId = formatVPCTemplateId() ]
        [#local vpcName = formatVPCName()]
        [#local legacyIGWId = formatVPCIGWTemplateId() ]
        [#local legacyIGWName = formatIGWName() ]
        [#local legacyIGWAttachmentId = formatId(AWS_VPC_IGW_ATTACHMENT_TYPE) ]
    [#else]
        [#local vpcId = formatResourceId(AWS_VPC_RESOURCE_TYPE, core.Id)]
        [#local vpcName = core.FullName ]
    [/#if]

    [#local networkCIDR = isPresent(network.CIDR)?then(
        network.CIDR.Address + "/" + network.CIDR.Mask,
        solution.Address.CIDR )]

    [#local subnetCIDRMask = getSubnetMaskFromSizes(
                                networkCIDR,
                                network.Tiers.Order?size,
                                network.Zones.Order?size )]
    [#local subnetCIDRS = getSubnetsFromNetwork(networkCIDR, subnetCIDRMask)]

    [#local subnets = {} ]
    [#-- Define subnets --]
    [#list getTiers()?filter(x -> x.Network.Enabled && x.Active ) as networkTier]
        [#if ! (networkTier?has_content && networkTier.Network.Enabled &&
                    networkTier.Network.Link.Tier == core.Tier.Id && networkTier.Network.Link.Component == core.Component.Id &&
                    (networkTier.Network.Link.Version!core.Version.Id) == core.Version.Id && (networkTier.Network.Link.Instance!core.Instance.Id) == core.Instance.Id  ) ]
            [#continue]
        [/#if]

        [#if ! (networkTier.Index)?is_number ]
            [#continue]
        [/#if]

        [#list getZones() as zone]
            [#local subnetId = legacyVpc?then(
                                    formatSubnetId(networkTier, zone),
                                    formatResourceId(AWS_VPC_SUBNET_RESOURCE_TYPE, core.Id, networkTier.Id, zone.Id))]

            [#local subnetName = legacyVpc?then(
                                    formatSubnetName(networkTier, zone),
                                    formatName(core.FullName, networkTier.Name, zone.Name))]

            [#local subnetIndex = ( networkTier.Index * network.Zones.Order?size ) + zone?index]
            [#local subnetCIDR = subnetCIDRS[subnetIndex]]
            [#local subnets =  mergeObjects( subnets, {
                networkTier.Id  : {
                    zone.Id : {
                        "subnet" : {
                            "Id" : subnetId,
                            "Name" : subnetName,
                            "Address" : subnetCIDR,
                            "Type" : AWS_VPC_SUBNET_TYPE
                        },
                        "routeTableAssoc" : {
                            "Id" : formatRouteTableAssociationId(subnetId),
                            "Type" : AWS_VPC_NETWORK_ROUTE_TABLE_ASSOCIATION_TYPE
                        },
                        "networkACLAssoc" : {
                            "Id" : formatNetworkACLAssociationId(subnetId),
                            "Type" : AWS_VPC_NETWORK_ACL_ASSOCIATION_TYPE
                        }
                    }
                }
            })]
        [/#list]
    [/#list]

    [#local flowLogs = {} ]
    [#list solution.Logging.FlowLogs as id,flowlog ]
        [#local flowLogId = formatResourceId(AWS_VPC_FLOWLOG_RESOURCE_TYPE, core.Id, id ) ]
        [#-- Needed to handle transition from flag based to explicit config based configuration --]
        [#-- of flowlogs for existing installations                                             --]
        [#local legacyFlowLogLgId = formatDependentLogGroupId(formatResourceId("vpc", core.Id, id )) ]
        [#local flowLogLgId =
            valueIfTrue(
                legacyFlowLogLgId,
                getExistingReference(legacyFlowLogLgId)?has_content,
                formatDependentLogGroupId(flowLogId)
            )
        ]

        [#local flowLogs += {
            id : {
                "flowLog" : {
                    "Id": flowLogId,
                    "Type" : AWS_VPC_FLOWLOG_RESOURCE_TYPE,
                    "Name" : formatName(core.FullName, id)
                }
            } +
            ( flowlog.DestinationType == "log" )?then(
                {
                    "flowLogRole" : {
                        "Id" : formatDependentRoleId(flowLogId),
                        "Type" : AWS_IAM_ROLE_RESOURCE_TYPE,
                        "IncludeInDeploymentState" : false
                    },
                    "flowLogLg" : {
                        "Id" : flowLogLgId,
                        "Name" : formatAbsolutePath(core.FullAbsolutePath, id),
                        "Type" : AWS_CLOUDWATCH_LOG_GROUP_RESOURCE_TYPE,
                        "IncludeInDeploymentState" : false
                    }
                },
                {}
            )
        }]
    [/#list]

    [#local dnsQueryLoggers = {}]
    [#list solution.Logging.DNSQuery as id, dnsQueryLog ]
        [#local dnsQueryLoggerId = formatResourceId(AWS_ROUTE53RESOLVER_RESOLVER_LOGGING_RESOURCE, core.Id, id)]
        [#local dnsQueryLoggerAssocId = formatResourceId(AWS_ROUTE53RESOLVER_RESOLVER_LOGGING_ASSOCIATION_RESOURCE, core.Id, id)]

        [#local dnsQueryLoggers += {
            id : {
                "dnsQueryLogger" : {
                    "Id" : dnsQueryLoggerId,
                    "Name" : formatName(core.FullName, id),
                    "Type" : AWS_ROUTE53RESOLVER_RESOLVER_LOGGING_RESOURCE
                },
                "dnsQueryLoggerAssoc" : {
                    "Id" : dnsQueryLoggerAssocId,
                    "Type" : AWS_ROUTE53RESOLVER_RESOLVER_LOGGING_ASSOCIATION_RESOURCE
                }
            } +
            attributeIfTrue(
                "dnsQueryLg",
                dnsQueryLog.DestinationType == "log",
                {
                    "Id" : formatDependentLogGroupId(dnsQueryLoggerId),
                    "Name" : formatAbsolutePath(core.FullAbsolutePath, "dnsquery", id),
                    "Type" : AWS_CLOUDWATCH_LOG_GROUP_RESOURCE_TYPE,
                    "IncludeInDeploymentState" : false
                }
            )
        }]
    [/#list]

    [#assign componentState =
        {
            "Resources" : {
                "vpc" : {
                    "Legacy" : legacyVpc,
                    "Id" : legacyVpc?then(formatVPCId(), vpcId),
                    "Legacy" : legacyVpc,
                    "ResourceId" : vpcId,
                    "Name" : vpcName,
                    "Address": networkCIDR,
                    "Type" : AWS_VPC_RESOURCE_TYPE
                },
                "subnets" : subnets
            } +
            legacyVpc?then(
                {
                    "legacyIGW" : {
                        "Id" : legacyVpc?then(formatVPCIGWId(), legacyIGWId),
                        "ResourceId" : legacyIGWId,
                        "Name" : legacyIGWName,
                        "Type" : AWS_VPC_IGW_RESOURCE_TYPE
                    },
                    "legacyIGWAttachment" : {
                        "Id" : legacyIGWAttachmentId,
                        "Type" : AWS_VPC_IGW_ATTACHMENT_TYPE
                    }
                },
                {}
            ) +
            attributeIfContent(
                "flowLogs",
                flowLogs
            ) +
            attributeIfContent(
                "dnsQueryLoggers",
                dnsQueryLoggers
            ),
            "Attributes" : {
                "VPC_ID" : getExistingReference(legacyVpc?then(formatVPCId(), vpcId))
            },
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]
[/#macro]

[#macro aws_networkroute_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local routeTables = {}]

    [#local routeTableId = formatResourceId(AWS_VPC_ROUTE_TABLE_RESOURCE_TYPE, core.Id)]
    [#local routeTableName = core.FullName ]

    [#local legacyVpc = parent.State.Resources["vpc"].Legacy]

    [#if legacyVpc ]
        [#-- Support for IGW defined as part of VPC tempalte instead of Gateway --]
        [#local legacyIGWRouteId = formatRouteId(routeTableId, "gateway") ]
    [/#if]

    [#list getTiers()?filter(x -> x.Active && x.Network.Enabled ) as networkTier]
        [#list getZones() as zone]
            [#local zoneRouteTableId = formatId(routeTableId, zone.Id)]
            [#local zoneRouteTableName = formatName(routeTableName, zone.Id)]

            [#local routeTables = mergeObjects(routeTables, {
                    zone.Id : {
                        "routeTable" : {
                            "Id" : zoneRouteTableId,
                            "Name" : zoneRouteTableName,
                            "Type" : AWS_VPC_ROUTE_TABLE_RESOURCE_TYPE
                        }
                    } +
                    (legacyVpc && solution.Public )?then(
                        {
                            "legacyIGWRoute" : {
                                "Id" : formatId(legacyIGWRouteId, zone.Id),
                                "Type" : AWS_VPC_ROUTE_RESOURCE_TYPE
                            }
                        },
                        {}
                    )
            })]
        [/#list]
    [/#list]

    [#assign componentState =
        {
            "Resources" : {
                "routeTables" : routeTables
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

[#macro aws_networkacl_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local legacyVpc = parent.State.Resources["vpc"].Legacy]

    [#if legacyVpc ]
        [#local networkACLId = formatNetworkACLId(core.SubComponent.Id) ]
        [#local networkACLName = formatNetworkACLName(core.SubComponent.Name)]
    [#else]
        [#local networkACLId = formatNetworkACLId(core.Id) ]
        [#local networkACLName = formatNetworkACLName(core.Name)]
    [/#if]

    [#local networkACLRules = {}]
    [#list solution.Rules as id, rule]
        [#local networkACLRules += {
            rule.Id : {
                "Id" :  formatDependentResourceId(
                            AWS_VPC_NETWORK_ACL_RULE_RESOURCE_TYPE,
                            networkACLId,
                            rule.Id),
                "Type" : AWS_VPC_NETWORK_ACL_RULE_RESOURCE_TYPE
            }
        }]
    [/#list]

    [#assign componentState =
        {
            "Resources" : {
                "networkACL" : {
                    "Id" : networkACLId,
                    "Name" : networkACLName,
                    "Type" : AWS_VPC_NETWORK_ACL_RESOURCE_TYPE
                },
                "rules" : networkACLRules
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
