[#ftl]

[#assign metricAttributes +=
    {
        AWS_VPNGATEWAY_VPN_CONNECTION_RESOURCE_TYPE : {
            "Namespace" : "AWS/VPN",
            "Dimensions" : {
                "VpnId" : {
                    "Output" : ""
                }
            }
        }
    }
]

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

[#function getVPNTunnelOptionsCli securityProfile ]

    [#local ikeVersions =
                (securityProfile.IKEVersions)?map( version -> { "Value" : version }) ]

    [#local phase1EncryptionAlgorithms =
                (securityProfile.Phase1.EncryptionAlgorithms)?map( algorithm -> { "Value" : algorithm})]

    [#local phase2EncryptionAlgorithms =
                (securityProfile.Phase2.EncryptionAlgorithms)?map( algorithm -> { "Value" : algorithm})]

    [#local phase1IntegrityAlgorithms =
                (securityProfile.Phase1.IntegrityAlgorithms)?map( algorithm -> { "Value" : algorithm})]

    [#local phase2IntegrityAlgorithms =
                (securityProfile.Phase2.IntegrityAlgorithms)?map( algorithm -> { "Value" : algorithm})]

    [#local phase1DHGroupNumbers =
                (securityProfile.Phase1.DiffeHellmanGroups)?map( groupNumber -> { "Value" : groupNumber})]

    [#local phase2DHGroupNumbers =
                (securityProfile.Phase1.DiffeHellmanGroups)?map( groupNumber -> { "Value" : groupNumber})]

    [#return
        {
            "TunnelOptions": {
                "RekeyMarginTimeSeconds": securityProfile.Rekey.MarginTime,
                "RekeyFuzzPercentage": securityProfile.Rekey.FuzzPercentage,
                "ReplayWindowSize": securityProfile.ReplayWindowSize,
                "DPDTimeoutSeconds": securityProfile.DeadPeerDetectionTimeout,
                "IKEVersions": ikeVersions,

                "Phase1LifetimeSeconds": securityProfile.Phase1.Lifetime,
                "Phase1EncryptionAlgorithms": phase1EncryptionAlgorithms,
                "Phase1IntegrityAlgorithms": phase1IntegrityAlgorithms,
                "Phase1DHGroupNumbers": phase1DHGroupNumbers,

                "Phase2LifetimeSeconds": securityProfile.Phase2.Lifetime,
                "Phase2EncryptionAlgorithms": phase2EncryptionAlgorithms,
                "Phase2IntegrityAlgorithms": phase2IntegrityAlgorithms,
                "Phase2DHGroupNumbers": phase2DHGroupNumbers
            }
        }
    ]
[/#function]
