[#ftl]
[#macro aws_externalnetwork_cf_generationcontract_segment occurrence ]
    [@addDefaultGenerationContract subsets="template" /]
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

                [#local vpnPublicIP = (solution.VPN.SiteToSite.PublicIP)!"" ]

                [#if ! vpnPublicIP?has_content ]
                    [@fatal
                        message="VPN Public IP Address not found"
                        context={ "VPN" : solution.VPN }
                    /]
                [/#if]

                [@createVPNCustomerGateway
                    id=customerGatewayId
                    name=customerGatewayName
                    custSideAsn=BGPASN
                    custVPNIP=vpnPublicIP
                /]
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

                    [#case "NETWORK_GATEWAY_COMPONENT_TYPE" ]
                        [#if linkTargetCore.Engine == "private" ]

                            [#local vpnGatewayId = linkTargetResources["privateGateway"].Id ]

                            [@createVPNConnection
                                id=vpnGatewayId
                                name=vpnGatewayName
                                staticRoutesOnly=( ! solution.BGP.Enabled )
                                customerGateway=getReference(customerGatewayId)
                                vpnGateway=getReference(vpnGatewayId)
                            /]
                        [#break]
                [/#switch]
        [/#list]
    [/#list]
[/#macro]
