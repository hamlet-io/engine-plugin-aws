[#ftl]

[#macro createTransitGateway
            id
            name
            amznSideAsn
            ecmpSupport
    ]

    [@cfResource
        id=id
        type="AWS::EC2::TransitGateway"
        properties=
            {
                "DefaultRouteTableAssociation" : "disable",
                "DefaultRouteTablePropagation" : "disable",
                "AmazonSideAsn" : amznSideAsn
            } +
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
            transitGateway
            subnets
            vpc
    ]

    [@cfResource
        id=id
        type="AWS::EC2::TransitGatewayAttachment"
        properties=
            {
                "SubnetIds" : subnets,
                "VpcId" : vpc,
                "TransitGatewayId" : transitGateway
            }
        tags=getCfTemplateCoreTags(name)
    /]
[/#macro]

[#macro createTransitGatewayRoute
            id
            transitGatewayRouteTable
            transitGatewayAttachment=""
            destinationCidr=""
            blackhole=false
    ]

    [@cfResource
        id=id
        type="AWS::EC2::TransitGatewayRoute"
        properties=
            {
                "TransitGatewayRouteTableId" : transitGatewayRouteTable
            } +
            attributeIfContent(
                "DestinationCidrBlock",
                destinationCidr
            ) +
            attributeIfTrue(
                "Blackhole",
                blackhole,
                blackhole
            ) +
            attributeIfContent(
                "TransitGatewayAttachmentId",
                transitGatewayAttachment
            )
    /]
[/#macro]

[#macro createTransitGatewayRouteTable
            id
            name
            transitGateway
    ]

    [@cfResource
        id=id
        type="AWS::EC2::TransitGatewayRouteTable"
        properties=
            {
                "TransitGatewayId" : transitGateway
            }
        tags=getCfTemplateCoreTags(name)
    /]
[/#macro]


[#macro createTransitGatewayRouteTableAssociation
            id
            transitGatewayAttachment
            transitGatewayRouteTable
    ]

    [@cfResource
        id=id
        type="AWS::EC2::TransitGatewayRouteTableAssociation"
        properties=
            {
                "TransitGatewayAttachmentId" : transitGatewayAttachment,
                "TransitGatewayRouteTableId" : transitGatewayRouteTable
            }
    /]
[/#macro]

[#macro createTransitGatewayRouteTablePropagation
            id
            transitGatewayAttachment
            transitGatewayRouteTable
    ]

    [@cfResource
        id=id
        type="AWS::EC2::TransitGatewayRouteTablePropagation"
        properties=
            {
                "TransitGatewayAttachmentId" : transitGatewayAttachment,
                "TransitGatewayRouteTableId" : transitGatewayRouteTable
            }
    /]
[/#macro]
