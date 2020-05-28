[#ftl]

[#macro createVPNCustomerGateway
            id
            name
            custSideAsn
            custVPNIP
    ]

    [@cfResource
        id=id
        type="AWS::EC2::CustomerGateway"
        properties=
            {
                "BgpAsn" : custSideAsn,
                "IpAddress" : custVPNIP,
                "Type" : "ipsec.1"
            }
        tags=getCfTemplateCoreTags(name)
    /]
[/#macro]

[#macro createVPNVirtualGateway
            id
            name
            bgpEnabled
            amznSideAsn=""
    ]

    [@cfResource
        id=id
        type="AWS::EC2::VPNGateway"
        properties=
            {
                "Type" : "ipsec.1"
            } +
            attributeIfTrue(
                "AmazonSideAsn",
                bgpEnabled,
                amznSideAsn
            )
        tags=getCfTemplateCoreTags(name)
    /]
[/#macro]

[#macro createVPNGatewayAttachment
            id
            vpcId
            vpnGatewayId]
    [@cfResource
        id=id
        type="AWS::EC2::VPCGatewayAttachment"
        properties=
            {
                "VpnGatewayId" : getReference(vpnGatewayId),
                "VpcId" : getReference(vpcId)
            }
        outputs={}
    /]
[/#macro]

[#macro createVPNConnection
            id
            name
            staticRoutesOnly
            customerGateway
            preSharedKey=""
            transitGateway=""
            vpnGateway=""
    ]

    [@cfResource
        id=id
        type="AWS::EC2::VPNConnection"
        properties=
            {
                "CustomerGatewayId" : customerGateway,
                "StaticRoutesOnly" : staticRoutesOnly,
                "Type" : "ipsec.1"
            } +
            attributeIfContent(
                "TransitGatewayId",
                transitGateway
            ) +
            attributeIfContent(
                "VpnGatewayId",
                vpnGateway
            )
        tags=getCfTemplateCoreTags(name)
    /]
[/#macro]

[#macro createVPNConnectionRoute
        id
        destinationCidr
        vpnConnectionId
    ]

    [@cfResource
        id=id
        type="AWS::EC2::VPNConnectionRoute"
        properties={
            "DestinationCidrBlock" : destinationCidr,
            "VpnConnectionId" : getReference(vpnConnectionId)
        }
    /]
[/#macro]

[#macro createVPNGatewayRoutePropogation
        id
        routeTableIds
        vpnGatewayId
    ]

    [@cfResource
        id=id
        type="AWS::EC2::VPNGatewayRoutePropagation"
        properties={
            "RouteTableIds" : getReferences(routeTableIds),
            "VpnGatewayId" : getReference(vpnGatewayId)
        }
    /]
[/#macro]
