[#ftl]
[#macro aws_externalnetwork_cf_generationcontract_segment occurrence ]
    [@addDefaultGenerationContract subsets=[ "template", "epilogue" ] /]
[/#macro]

[#macro aws_externalnetwork_cf_setup_segment occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local parentCore = occurrence.Core ]
    [#local parentSolution = occurrence.Configuration.Solution ]
    [#local parentResources = occurrence.State.Resources ]

    [#local BGPASN = parentSolution.BGP.ASN ]

    [#list occurrence.Occurrences![] as subOccurrence]

        [@debug message="Suboccurrence" context=subOccurrence enabled=false /]

        [#local core = subOccurrence.Core ]
        [#local solution = subOccurrence.Configuration.Solution ]
        [#local resources = subOccurrence.State.Resources ]

        [#if !(solution.Enabled!false)]
            [#continue]
        [/#if]

        [#switch solution.Engine ]
            [#case "SiteToSite" ]
                [#local customerGatewayId = resources["customerGateway"].Id ]
                [#local customerGatewayName = resources["customerGateway"].Name ]

                [#local vpnGatewayId = resources["vpnConnection"].Id ]
                [#local vpnGatewayName = resources["vpnConnection"].Name ]

                [#local vpnPublicIP = (solution.SiteToSite.PublicIP)!"" ]

                [#if ! vpnPublicIP?has_content ]
                    [@fatal
                        message="VPN Public IP Address not found"
                        context={ "SiteToSite" : solution.SiteToSite }
                    /]
                [/#if]

                [#if deploymentSubsetRequired(EXTERNALNETWORK_COMPONENT_TYPE, true)]
                    [@createVPNCustomerGateway
                        id=customerGatewayId
                        name=customerGatewayName
                        custSideAsn=BGPASN
                        custVPNIP=vpnPublicIP
                    /]
                [/#if]
                [#break]
        [/#switch]

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
                    [#case NETWORK_ROUTER_COMPONENT_TYPE ]

                        [#switch solution.Engine ]
                            [#case "SiteToSite" ]

                                [#local vpnConnectionId = formatResourceId(
                                            AWS_VPNGATEWAY_VPN_CONNECTION_RESOURCE_TYPE,
                                            core.Id,
                                            linkTarget.Core.Id
                                        )]

                                [#local transitGateway = getReference( linkTargetResources["transitGateway"].Id ) ]
                                [#local transitGatewayRouteTable = getReference( linkTargetResources["routeTable"].Id )]
                                [#local transGatewayAttachmentId =  formatId(vpnConnectionId, "attach") ]

                                [#if deploymentSubsetRequired(EXTERNALNETWORK_COMPONENT_TYPE, true)]
                                    [@createVPNConnection
                                        id=vpnConnectionId
                                        name=formatName(core.FullName, linkTargetCore.Name)
                                        staticRoutesOnly=( ! parentSolution.BGP.Enabled )
                                        customerGateway=getReference(customerGatewayId)
                                        transitGateway=transitGateway
                                    /]
                                [/#if]

                                [#if getExistingReference(transGatewayAttachmentId)?has_content ]

                                    [#if deploymentSubsetRequired(EXTERNALNETWORK_COMPONENT_TYPE, true)]
                                        [@createTransitGatewayRouteTableAssociation
                                                id=formatResourceId(
                                                    AWS_TRANSITGATEWAY_ATTACHMENT_RESOURCE_TYPE,
                                                    core.Id,
                                                    linkTargetCore.Id
                                                )
                                                transitGatewayAttachment=getExistingReference(transGatewayAttachmentId)
                                                transitGatewayRouteTable=transitGatewayRouteTable
                                        /]
                                    [/#if]

                                    [#if parentSolution.BGP.Enabled ]

                                        [#if deploymentSubsetRequired(EXTERNALNETWORK_COMPONENT_TYPE, true)]
                                            [@createTransitGatewayRouteTablePropagation
                                                    id=formatResourceId(
                                                        AWS_TRANSITGATEWAY_ROUTETABLE_PROPOGATION_TYPE,
                                                        core.Id,
                                                        linkTargetCore.Id
                                                    )
                                                    transitGatewayAttachment=getExistingReference(transGatewayAttachmentId)
                                                    transitGatewayRouteTable=transitGatewayRouteTable
                                            /]
                                        [/#if]

                                    [#else]

                                        [#local externalNetworkCIDRs = getGroupCIDRs(parentSolution.IPAddressGroups, true, occurrence)]

                                        [#list externalNetworkCIDRs as externalNetworkCIDR ]
                                            [#local vpnRouteId = formatResourceId(
                                                    AWS_TRANSITGATEWAY_ROUTE_RESOURCE_TYPE,
                                                    core.Id,
                                                    linkTarget.Core.Id,
                                                    externalNetworkCIDR?index
                                            )]

                                            [#if deploymentSubsetRequired(EXTERNALNETWORK_COMPONENT_TYPE, true)]
                                                [@createTransitGatewayRoute
                                                        id=vpnRouteId
                                                        transitGatewayRouteTable=transitGatewayRouteTable
                                                        transitGatewayAttachment=getExistingReference(transGatewayAttachmentId)
                                                        destinationCidr=externalNetworkCIDR
                                                /]
                                            [/#if]
                                        [/#list]
                                    [/#if]
                                [#else]

                                    [#if deploymentSubsetRequired("epilogue", false) ]
                                        [@addToDefaultBashScriptOutput
                                            content=[
                                                r'warning "Please run another update to the gateway to create routes"'
                                            ]
                                        /]
                                    [/#if]
                                [/#if]

                                [#if deploymentSubsetRequired("epilogue", false) ]
                                    [@addToDefaultBashScriptOutput
                                        content=[
                                            r'transitGatewayAttachment="$(get_transitgateway_vpn_attachment' +
                                            r' "' + region + r'" ' +
                                            r' "${STACK_NAME}"' +
                                            r' "' + vpnConnectionId + r'" )"'
                                        ] +
                                        pseudoStackOutputScript(
                                            "VPN Gateway Attachment",
                                            {
                                               transGatewayAttachmentId : r'${transitGatewayAttachment}'
                                            }
                                            vpnConnectionId
                                        )
                                    /]
                                [/#if]
                                [#break]
                        [/#switch]
                        [#break]
                [/#switch]
            [/#if]
        [/#list]
    [/#list]
[/#macro]
