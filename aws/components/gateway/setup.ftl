[#ftl]
[#macro aws_gateway_cf_generationcontract_segment occurrence ]
    [@addDefaultGenerationContract subsets="template" /]
[/#macro]

[#macro aws_gateway_cf_setup_segment occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local gwCore = occurrence.Core ]
    [#local gwSolution = occurrence.Configuration.Solution ]
    [#local gwResources = occurrence.State.Resources ]

    [#local tags = getOccurrenceCoreTags(occurrence, gwCore.FullName, "", true)]

    [#local occurrenceNetwork = getOccurrenceNetwork(occurrence) ]
    [#local networkLink = occurrenceNetwork.Link!{} ]

    [#if !networkLink?has_content ]
        [@fatal
            message="Tier Network configuration incomplete"
            context=
                {
                    "networkTier" : occurrenceNetwork,
                    "Link" : networkLink
                }
        /]

    [#else]

        [#local networkLinkTarget = getLinkTarget(occurrence, networkLink, false) ]
        [#if ! networkLinkTarget?has_content ]
            [@fatal message="Network could not be found" context=networkLink /]
            [#return]
        [/#if]

        [#local networkConfiguration = networkLinkTarget.Configuration.Solution]
        [#local networkResources = networkLinkTarget.State.Resources ]

        [#local legacyIGW = (networkResources["legacyIGW"]!{})?has_content]

        [#local vpcId = networkResources["vpc"].Id ]
        [#local vpcPrivateDNS = networkConfiguration.DNS.UseProvider && networkConfiguration.DNS.GenerateHostNames]

        [#local sourceIPAddressGroups = gwSolution.SourceIPAddressGroups ]
        [#local sourceCidrs = getGroupCIDRs(sourceIPAddressGroups, true, occurrence)]

        [#-- create Elastic IPs --]
        [#list gwResources["Zones"] as zone, zoneResources ]
            [#if (zoneResources["eip"]!{})?has_content ]
                [#local eipId = zoneResources["eip"].Id ]
                [#local eipName = zoneResources["eip"].Name ]
                [#if deploymentSubsetRequired("eip", true) &&
                        isPartOfCurrentDeploymentUnit(eipId)]

                    [@createEIP
                        id=eipId
                        tags=[]
                    /]

                [/#if]
            [/#if]
        [/#list]

        [#-- Gateway Creation --]
        [#switch gwSolution.Engine ]
            [#case "natgw"]
                [#list gwResources["Zones"] as zone, zoneResources ]
                    [#local natGatewayId = zoneResources["natGateway"].Id ]
                    [#local natGatewayName = zoneResources["natGateway"].Name ]
                    [#local eipId = zoneResources["eip"].Id]

                    [#local subnetId = (networkResources["subnets"][gwCore.Tier.Id][zone])["subnet"].Id]

                    [#local natGwTags = getOccurrenceCoreTags(
                                                occurrence,
                                                natGatewayName,
                                                "",
                                                false)]
                    [#if deploymentSubsetRequired(NETWORK_GATEWAY_COMPONENT_TYPE, true)]
                        [@createNATGateway
                            id=natGatewayId
                            subnetId=subnetId
                            eipId=eipId
                            tags=natGwTags
                        /]
                    [/#if]

                [/#list]
            [#break]

            [#case "igw"]

                [#if !legacyIGW ]
                    [#local IGWId = gwResources["internetGateway"].Id ]
                    [#local IGWName = gwResources["internetGateway"].Name ]
                    [#local IGWAttachementId = gwResources["internetGatewayAttachement"].Id ]

                    [#if deploymentSubsetRequired(NETWORK_GATEWAY_COMPONENT_TYPE, true)]
                        [@createIGW
                            id=IGWId
                            name=IGWName
                        /]
                        [@createIGWAttachment
                            id=IGWAttachementId
                            vpcId=vpcId
                            igwId=IGWId
                        /]
                    [/#if]
                [/#if]
            [#break]

            [#case "vpcendpoint"]
            [#break]

            [#case "router"]
                [#local transitGateway = ""]
                [#local transitGatewayRouteTable = ""]

                [#local routerFound = false]

                [#local attachementSubnets = [] ]
                [#list networkResources["subnets"][gwCore.Tier.Id] as zone,resources]
                    [#local attachementSubnets += [ resources["subnet"].Id ] ]
                [/#list]

                [#local transitGatewayAttachementId = gwResources["transitGatewayAttachement"].Id ]
                [#local transitGatewayAttachementName = gwResources["transitGatewayAttachement"].Name ]
                [#local transitGatewayRoutePropogationId = gwResources["routePropogation"].Id ]
                [#local routeTableAssociationId = gwResources["routeAssociation"].Id ]
                [#break]

            [#case "private" ]
                [#local privateGatewayId = gwResources["privateGateway"].Id ]
                [#local privateGatewayName = gwResources["privateGateway"].Name ]
                [#local privateGatewayAttachmentId = gwResources["privateGatewayAttachment"].Id ]

                [@createVPNVirtualGateway
                    id=privateGatewayId
                    name=privateGatewayName
                    bgpEnabled=gwSolution.BGP.Enabled
                    amznSideAsn=gwSolution.BGP.ASN
                /]

                [@createVPNGatewayAttachment
                    id=privateGatewayAttachmentId
                    vpcId=vpcId
                    vpnGatewayId=privateGatewayId
                /]
                [#break]


        [/#switch]

        [#-- Security Group Creation --]

        [#local securityGroupId=""]
        [#local securityGroupName=""]

        [#switch gwSolution.Engine ]
            [#case "vpcendpoint" ]
                [#local securityGroupId = gwResources["sg"].Id]
                [#local securityGroupName = gwResources["sg"].Name ]

                [#if deploymentSubsetRequired(NETWORK_GATEWAY_COMPONENT_TYPE, true)]
                    [@createSecurityGroup
                        id=securityGroupId
                        name=securityGroupName
                        occurrence=occurrence
                        vpcId=vpcId
                        /]

                    [#list sourceCidrs as cidr ]

                        [@createSecurityGroupIngress
                            id=
                                formatDependentSecurityGroupIngressId(
                                    securityGroupId,
                                    replaceAlphaNumericOnly(cidr)
                                )
                            port=""
                            cidr=cidr
                            groupId=securityGroupId
                    /]
                    [/#list]
                [/#if]
                [#break]
        [/#switch]

        [#list gwSolution.Links?values as link]
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

                    [#case EXTERNALNETWORK_CONNECTION_COMPONENT_TYPE ]
                        [#if gwSolution.Engine == "private" ]

                        [/#if]

                        [#break]

                    [#case NETWORK_ROUTER_COMPONENT_TYPE]
                        [#if gwSolution.Engine == "router" ]

                            [#if routerFound ]
                                [@fatal
                                    message="Multiple routers found, only one per gateway is supported"
                                    context=gwSolution.Links
                                /]
                                [#continue]
                            [/#if]

                            [#local routerFound = true ]
                            [#local transitGateway = getExistingReference( linkTargetResources["transitGateway"].Id ) ]
                            [#local transitGatewayRouteTableId = getExistingReference( linkTargetResources["routeTable"].Id ) ]

                        [/#if]
                        [#break]

                    [#case EXTERNALSERVICE_COMPONENT_TYPE]
                        [#if gwSolution.Engine == "router" ]
                            [#local transitGateway = linkTargetAttributes["TRANSIT_GATEWAY_ID"]!"" ]
                            [#local transitGatewayRouteTable = linkTargetAttributes["ROUTE_TABLE_ID"]!"" ]

                            [#if transitGateway?has_content && transitGatewayRouteTable?has_content ]
                                [#local routerFound = true ]
                            [#else]
                                [@fatal
                                    message="Could not find Attributes for external Transit Gateway or multiple gateways set"
                                    context={
                                        "TRANSIT_GATEWAY_ID" : linkTargetAttributes["TRANSIT_GATEWAY_ID"]!"",
                                        "ROUTE_TABLE_ID" : linkTargetAttributes["ROUTE_TABLE_ID"]!""
                                    }
                                /]
                                [#continue]
                            [/#if]
                        [/#if]
                        [#break]
                [/#switch]
            [/#if]
        [/#list]

        [#-- processing based on links --]
        [#switch gwSolution.Engine ]
            [#case "router"]
                [#if ! routerFound ]
                    [@fatal
                        message="Router not found - make sure the router is deployed and a link has been added"
                        context=gwSolution.Links
                    /]
                [/#if]

                [@createTransitGatewayAttachment
                    id=transitGatewayAttachementId
                    name=transitGatewayAttachementName
                    transitGateway=transitGateway
                    subnets=getReferences(attachementSubnets)
                    vpc=getReference(vpcId)
                /]

                [@createTransitGatewayRouteTablePropagation
                    id=transitGatewayRoutePropogationId
                    transitGatewayAttachment=getReference(transitGatewayAttachementId)
                    transitGatewayRouteTable=transitGatewayRouteTable
                /]

                [@createTransitGatewayRouteTableAssociation
                    id=routeTableAssociationId
                    transitGatewayAttachment=getReference(transitGatewayAttachementId)
                    transitGatewayRouteTable=transitGatewayRouteTable
                /]
                [#break]
        [/#switch]

        [#list occurrence.Occurrences![] as subOccurrence]

            [@debug message="Suboccurrence" context=subOccurrence enabled=false /]

            [#local core = subOccurrence.Core ]
            [#local solution = subOccurrence.Configuration.Solution ]
            [#local resources = subOccurrence.State.Resources ]

            [#if !(solution.Enabled!false)]
                [#continue]
            [/#if]

            [#-- Determine the IP whitelisting required --]
            [#local destinationIPAddressGroups = solution.IPAddressGroups ]
            [#local cidrs = getGroupCIDRs(destinationIPAddressGroups, true, subOccurrence)]

            [#local routeTableIds = []]
            [#local privateGatewayDependencies = []]

            [#list solution.Links?values as link]
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

                        [#case EXTERNALNETWORK_CONNECTION_COMPONENT_TYPE ]
                            [#switch linkTargetConfiguration.Solution.Engine ]

                                [#case "SiteToSite" ]

                                    [#local customerGateway = linkTargetAttributes["CUSTOMER_GATEWAY_ID"]]
                                    [#local externalNetworkCIDRs = linkTargetAttributes["NETWORK_ADDRESSES"]?split(",")]

                                    [#local vpnConnectionId = formatResourceId(
                                                AWS_VPNGATEWAY_VPN_CONNECTION_RESOURCE_TYPE,
                                                core.Id,
                                                linkTarget.Core.Id
                                            )]

                                    [@createVPNConnection
                                            id=vpnConnectionId
                                            name=formatName(core.FullName, linkTargetCore.Name)
                                            staticRoutesOnly=( ! (linkTargetAttributes["BGP_ASN"]!"")?has_content)
                                            customerGateway=customerGateway
                                            vpnGateway=getReference(privateGatewayId)
                                    /]

                                    [#list externalNetworkCIDRs as externalNetworkCIDR ]
                                        [#local vpnConnectionRouteId = formatResourceId(
                                                AWS_VPNGATEWAY_VPN_CONNECTION_ROUTE_RESOURCE_TYPE,
                                                core.Id,
                                                linkTarget.Core.Id,
                                                externalNetworkCIDR?index
                                        )]

                                        [@createVPNConnectionRoute
                                            id=vpnConnectionRouteId
                                            vpnConnectionId=vpnConnectionId
                                            destinationCidr=externalNetworkCIDR
                                        /]
                                    [/#list]

                                    [#local privateGatewayDependencies += [ vpnConnectionId ]]

                                    [#break]

                            [/#switch]
                            [#break]

                    [/#switch]
                [/#if]
            [/#list]



            [#-- Second round of processing for routes as they depend on other links --]
            [#list solution.Links?values as link]
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
                        [#case NETWORK_ROUTE_TABLE_COMPONENT_TYPE]

                            [#local publicRouteTable = linkTargetConfiguration.Solution.Public ]

                            [#list linkTargetResources["routeTables"] as zone, zoneRouteTableResources ]

                                [#local zoneRouteTableId = zoneRouteTableResources["routeTable"].Id]
                                [#local routeTableIds += [ zoneRouteTableId ]]

                                    [#if deploymentSubsetRequired(NETWORK_GATEWAY_COMPONENT_TYPE, true)]

                                    [#switch gwSolution.Engine ]
                                        [#case "natgw" ]
                                            [#local zoneResources = gwResources["Zones"]]
                                            [#if multiAZ ]
                                                [#local natGatewayId = (zoneResources[zone]["natGateway"]).Id]
                                            [#else]
                                                [#local natGatewayId = (zoneResources[(zones[0].Id)]["natGateway"]).Id]
                                            [/#if]
                                            [#list cidrs as cidr ]
                                                [@createRoute
                                                    id=formatRouteId(zoneRouteTableId, core.Id, cidr?index)
                                                    routeTableId=zoneRouteTableId
                                                    destinationType="nat"
                                                    destinationAttribute=getReference(natGatewayId)
                                                    destinationCidr=cidr
                                                /]
                                            [/#list]
                                            [#break]

                                        [#case "igw"]

                                            [#if !legacyIGW ]
                                                [#if publicRouteTable ]
                                                    [#list cidrs as cidr ]
                                                        [@createRoute
                                                            id=formatRouteId(zoneRouteTableId, core.Id, cidr?index)
                                                            routeTableId=zoneRouteTableId
                                                            destinationType="gateway"
                                                            destinationAttribute=getReference(IGWId)
                                                            destinationCidr=cidr
                                                            dependencies=IGWAttachementId
                                                        /]
                                                    [/#list]
                                                [#else]
                                                    [@fatal
                                                        message="Cannot add internet gateway to private route table. Route table must be public"
                                                        context={ "Gateway" : subOccurrence, "RouteTable" :  link }
                                                    /]
                                                [/#if]
                                            [/#if]
                                            [#break]

                                        [#case "router"]
                                            [#list cidrs as cidr ]
                                                [@createRoute
                                                    id=formatRouteId(zoneRouteTableId, core.Id, cidr?index)
                                                    routeTableId=zoneRouteTableId
                                                    destinationType="transit"
                                                    destinationAttribute=transitGateway
                                                    destinationCidr=cidr
                                                    dependencies=transitGatewayAttachementId
                                                /]
                                            [/#list]
                                            [#break]

                                        [#case "private" ]
                                            [#if solution.DynamicRouting ]
                                                [@createVPNGatewayRoutePropogation
                                                    id=formatResourceId(
                                                        AWS_VPNGATEWAY_VIRTUAL_GATEWAY_PROPOGATION_RESOURCE_TYPE,
                                                        core.Id,
                                                        zoneRouteTableId
                                                    )
                                                    routeTableIds=zoneRouteTableId
                                                    vpnGatewayId=privateGatewayId
                                                /]
                                            [#else]
                                                [#list cidrs as cidr ]
                                                    [@createRoute
                                                        id=formatRouteId(zoneRouteTableId, core.Id, cidr?index )
                                                        routeTableId=zoneRouteTableId
                                                        destinationType="gateway"
                                                        destinationAttribute=getReference(privateGatewayId)
                                                        destinationCidr=cidr
                                                        dependencies=privateGatewayDependencies
                                                    /]
                                                [/#list]
                                            [/#if]
                                            [#break]

                                        [#case "endpoint" ]
                                            [#local endpointScope = (gwSolution.EndpointScope)!"COTFatal: EndpointScope not defined - required for endpoint engine" ]
                                            [#local endpointType = (gwSolution.EndpointType)!"COTFatal: EndpointType not defined - required for endpoint engine" ]

                                            [#switch endpointScope ]
                                                [#case "zone" ]
                                                    [#local zoneResources = gwResources["Zones"]]
                                                    [#if multiAZ ]
                                                        [#local gateway = zoneResources[zone]["endpoint"] ]
                                                    [#else]
                                                        [#local gateway = zoneResources[zones[0]]["endpoint"] ]
                                                    [/#if]
                                                    [#break]

                                                [#case "network" ]
                                                    [#local gateway = gwResources["endpoint"]]
                                                    [#break]
                                            [/#switch]

                                            [#list cidrs as cidr ]
                                                [@createRoute
                                                    id=formatRouteId(zoneRouteTableId, core.Id, cidr?index)
                                                    routeTableId=zoneRouteTableId
                                                    destinationType=endpointType
                                                    destinationAttribute=gateway.EndpointAttribute
                                                    destinationCidr=cidr
                                                /]
                                            [/#list]

                                            [#break]
                                        [/#switch]
                                    [/#if]
                                [/#list]
                            [#break]

                    [/#switch]
                [/#if]
            [/#list]

            [#switch gwSolution.Engine ]
                [#case "vpcendpoint" ]
                    [#local vpcEndpointResources = resources["vpcEndpoints"]!{} ]
                    [#if deploymentSubsetRequired(NETWORK_GATEWAY_COMPONENT_TYPE, true)]

                        [#list vpcEndpointResources as resourceId, zoneVpcEndpoint ]
                            [#local endpointSubnets = [] ]
                            [#list networkResources["subnets"][gwCore.Tier.Id] as zone,resources]
                                [#if zoneVpcEndpoint.EndpointZones?seq_contains(zone )]
                                    [#local endpointSubnets += [ resources["subnet"].Id ] ]
                                [/#if]
                            [/#list]
                            [@createVPCEndpoint
                                id=zoneVpcEndpoint.Id
                                vpcId=vpcId
                                service=zoneVpcEndpoint.ServiceName
                                type=zoneVpcEndpoint.EndpointType
                                routeTableIds=routeTableIds
                                subnetIds=endpointSubnets
                                privateDNSZone=vpcPrivateDNS
                                securityGroupIds=securityGroupId
                            /]
                        [/#list]
                    [/#if]
                    [#break]
            [/#switch]
        [/#list]
    [/#if]
[/#macro]
