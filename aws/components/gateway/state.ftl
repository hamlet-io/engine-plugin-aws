[#ftl]

[#macro aws_gateway_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]
    [#local engine = solution.Engine ]
    [#local resources = {} ]
    [#local zoneResources = {}]

    [#if multiAZ!false ]
        [#local resourceZones = zones ]
    [#else]
        [#local resourceZones = [ zones[0] ]]
    [/#if]

    [#-- elastic IP address Allocation --]
    [#switch engine ]
        [#case "natgw" ]
        [#case "instance" ]
            [#list resourceZones as zone ]
                [#local eipId = legacyVpc?then(
                                    formatResourceId(AWS_EIP_RESOURCE_TYPE, core.Tier.Id, core.Component.Id, zone.Id),
                                    formatResourceId(AWS_EIP_RESOURCE_TYPE, core.Id, zone.Id))]
                [#local zoneResources = mergeObjects( zoneResources,
                        {
                            zone.Id : {
                                "eip" : {
                                    "Id" : eipId,
                                    "Name" : formatName(core.FullName, zone.Name),
                                    "Type" : AWS_EIP_RESOURCE_TYPE
                                }
                            }
                        } )]
            [/#list]
            [#break]
    [/#switch]

    [#switch engine ]
        [#case "natgw"]

            [#list resourceZones as zone]
                [#local natGatewayId = legacyVpc?then(
                                            formatNATGatewayId(core.Tier.Id, zone.Id),
                                            formatResourceId(AWS_VPC_NAT_GATEWAY_RESOURCE_TYPE, core.Id, zone.Id)
                )]

                [#local zoneResources = mergeObjects(zoneResources,
                        {
                            zone.Id : {
                                "natGateway" : {
                                    "Id" : natGatewayId,
                                    "Name" : formatName(core.FullName, zone.Name),
                                    "Type" : AWS_VPC_NAT_GATEWAY_RESOURCE_TYPE
                                }
                            }
                        })]
            [/#list]
            [#break]

        [#case "igw"]
            [#if !legacyVpc ]
                [#local resources += {
                    "internetGateway" : {
                        "Id" : formatResourceId(AWS_VPC_IGW_RESOURCE_TYPE, core.Id),
                        "Name" : core.FullName,
                        "Type" : AWS_VPC_IGW_RESOURCE_TYPE
                    },
                    "internetGatewayAttachement" : {
                        "Id" : formatId(AWS_VPC_IGW_ATTACHMENT_TYPE, core.Id),
                        "Type" : AWS_VPC_IGW_ATTACHMENT_TYPE
                    }
                }]
            [/#if]
            [#break]

        [#case "vpcendpoint"]
                [#local resources += {
                    "sg" : {
                        "Id" : formatDependentSecurityGroupId(core.Id),
                        "Name" : core.FullName,
                        "Type" : AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE
                    }
                }]
            [#break]

        [#case "endpoint" ]

            [#local scope = solution.EndpointScope]

            [#list solution.Endpoints as id,endpoint ]
                [#local endpointLink = getLinkTarget(occurrence, endpoint.Link)]

                [#if endpointLink?has_content ]
                    [#switch scope ]

                        [#case "zone" ]

                            [#local endpointZone = zones[endpoint.Zone] ]

                            [#if asArray(zoneResources)?seq_contains( endpointZone.Id )]
                                [#local zoneResources = mergeObjects(
                                        zoneResources,
                                        {
                                            endpointZone.Id : {
                                                "endpoint" : {
                                                    "Id" : formatResourceId( AWS_VPC_ENDPOINT_RESOURCE_TYPE, core.Id, endpointZone.Id),
                                                    "EndpointAttribute" : (endpointLink.State.Attributes[endpoint.Attribute])!"",
                                                    "Type" : AWS_VPC_ENDPOINT_RESOURCE_TYPE
                                                }
                                            }
                                        }
                                )]
                            [/#if]
                            [#break]

                        [#case "network" ]
                            [#local resources = mergeObjects(
                                    resources,
                                    {
                                        "endpoint" : {
                                            "Id" : formatResourceId( AWS_VPC_ENDPOINT_RESOURCE_TYPE, core.Id ),
                                            "EndpointAttribute" : (endpointLink.State.Attributes[endpoint.Attribute])!"",
                                            "Type" : AWS_VPC_ENDPOINT_RESOURCE_TYPE
                                        }
                                    }
                            )]
                            [#break]
                    [/#switch]
                [/#if]
            [/#list]
            [#break]

        [#default]
            [@fatal
                message="Unknown Engine Type"
                context=occurrence.Configuration.Solution
            /]
    [/#switch]

    [#assign componentState =
        {
            "Resources" :
                resources +
                {
                    "Zones" : zoneResources
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

[#macro aws_gatewaydestination_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local parentCore = parent.Core]
    [#local parentSolution = parent.Configuration.Solution ]
    [#local engine = parentSolution.Engine ]

    [#if multiAZ!false || engine == "vpcendpoint" ]
        [#local resourceZones = zones ]
    [#else]
        [#local resourceZones = [zones[0]] ]
    [/#if]

    [#local resources = {} ]

    [#switch engine ]
        [#case "natgw"]
        [#case "igw"]
        [#case "endpoint" ]
            [#break]

        [#case "vpcendpoint"]

            [#local endpointZones = {} ]
            [#list resourceZones as zone]
                [#local networkEndpoints = getNetworkEndpoints(solution.NetworkEndpointGroups, zone.Id, regionId)]
                [#list networkEndpoints as id, networkEndpoint  ]
                    [#local endpointTypeZones = endpointZones[id]![] ]
                    [#local endpointZones += { id : endpointTypeZones + [ zone.Id ] }]
                    [#local resources = mergeObjects( resources, {
                        "vpcEndpoints" : {
                            "vpcEndpoint" + id : {
                                "Id" : formatResourceId(AWS_VPC_VPCENDPOINT_RESOURCE_TYPE, core.Id, replaceAlphaNumericOnly(id, "X")),
                                "EndpointType" : networkEndpoint.Type?lower_case,
                                "EndpointZones" : endpointZones[id],
                                "ServiceName" : networkEndpoint.ServiceName,
                                "Type" : AWS_VPC_VPCENDPOINT_RESOURCE_TYPE
                            }
                        }
                    })]
                [/#list]
            [/#list]
            [#break]

        [#default]
            [@fatal
                message="Unknown Engine Type"
                context=occurrence.Configuration.Solution
            /]
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
