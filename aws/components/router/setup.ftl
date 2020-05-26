[#ftl]
[#macro aws_router_cf_generationcontract_segment occurrence ]
    [@addDefaultGenerationContract subsets="template" /]
[/#macro]

[#macro aws_router_cf_setup_segment occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]

    [#local transitGatewayId = resources["transitGateway"].Id ]
    [#local transitGatewayName = resources["transitGateway"].Name ]
    [#local routeTableId = resources["routeTable"].Id ]
    [#local routeTableName = resources["routeTable"].Name ]

    [#local BGPConfiguration = solution.BGP]

    [#if deploymentSubsetRequired(NETWORK_ROUTER_COMPONENT_TYPE, true)]

        [@createTransitGateway
            id=transitGatewayId
            name=transitGatewayName
            bgpEnabled=BGPConfiguration.Enabled
            amznSideAsn=BGPConfiguration.ASN
            ecmpSupport=BGPConfiguration.ECMP
        /]

        [@createTransitGatewayRouteTable
            id=routeTableId
            name=routeTableName
            transitGatewayId=transitGatewayId
        /]

    [/#if]

[/#macro]
