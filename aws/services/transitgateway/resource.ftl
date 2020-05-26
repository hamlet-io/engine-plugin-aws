[#ftl]

[#macro createTransitGateway
            id
            name
            bgpEnabled
            amznSideAsn
            ecmpSupport
    ]

    [@cfResource
        id=id
        type="AWS::EC2::TransitGateway"
        properties=
            {
                "DefaultRouteTableAssociation" : "disable",
                "DefaultRouteTablePropagation" : "disable"
            } +
            attributeIfTrue(
                "AmazonSideAsn",
                bgpEnabled,
                amznSideAsn
            ) +
            attributeIfTrue(
                "VpnEcmpSupport",
                bgpEnabled,
                ecmpSupport?then(
                    "enable",
                    "disable"
                )
            )
        tags=getCfTemplateCoreTags(name)
    /]
[/#macro]

[#macro createTransitGatewayAttachment
            id
            name
            transitGatewayId
            subnetIds
            vpcId
    ]

    [@cfResource
        id=id
        type="AWS::EC2::TransitGatewayAttachment"
        properties=
            {
                "SubnetIds" : getReferences(subnetIds),
                "TransitGatewayId" : getReference(transitGatewayId),
                "VpcId" : getReference(vpcId)
            }
        tags=getCfTemplateCoreTags(name)
    /]
[/#macro]

[#macro createTransitGatewayRoute
            id
            transitGatewayRouteTableId
            transitGatewayAttachmentId=""
            destinationCidr=""
            blackhole=false
    ]

    [@cfResource
        id=id
        type="AWS::EC2::TransitGatewayRoute"
        properties=
            {
                "TransitGatewayRouteTableId" : getReference(transitGatewayRouteTableId)
            } +
            attributeIfContent(
                "DestinationCidrBlock",
                destinationCidr
            ) +
            attributeIftrue(
                "Blackhole",
                blackhole
            ) +
            attributeIfContent(
                "TransitGatewayAttachmentId",
                getReference(transitGatewayAttachmentId)
            )
    /]
[/#macro]

[#macro createTransitGatewayRouteTable
            id
            name
            transitGatewayId
    ]

    [@cfResource
        id=id
        type="AWS::EC2::TransitGatewayRouteTable"
        properties=
            {
                "TransitGatewayId" : getReference(transitGatewayId)
            }
        tags=getCfTemplateCoreTags(name)
    /]
[/#macro]


[#macro createTransitGatewayRouteTableAssociation
            id
            transitGatewayAttachmentId
            transitGatewayRouteTableId
    ]

    [@cfResource
        id=id
        type="AWS::EC2::TransitGatewayRouteTableAssociation"
        properties=
            {
                "TransitGatewayAttachmentId" : getReference(transitGatewayAttachmentId),
                "TransitGatewayRouteTableId" : getReference(transitGatewayRouteTableId)
            }
    /]
[/#macro]

[#macro createTransitGatewayRouteTablePropogation
            id
            transitGatewayAttachmentId
            transitGatewayRouteTableId
    ]

    [@cfResource
        id=id
        type="AWS::EC2::TransitGatewayRouteTablePropagation"
        properties=
            {
                "TransitGatewayAttachmentId" : getReference(transitGatewayAttachmentId),
                "TransitGatewayRouteTableId" : getReference(transitGatewayRouteTableId)
            }
    /]
[/#macro]
