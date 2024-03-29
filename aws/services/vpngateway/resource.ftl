[#ftl]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_VPNGATEWAY_VPN_CONNECTION_RESOURCE_TYPE
    mappings={
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
/]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_VPNGATEWAY_VPN_CONNECTION_TUNNEL_RESOURCE_TYPE
    mappings={
        IP_ADDRESS_ATTRIBUTE_TYPE : {
            "Attribute" : IP_ADDRESS_ATTRIBUTE_TYPE
        }
    }
/]

[@addCWMetricAttributes
    resourceType=AWS_VPNGATEWAY_VPN_CONNECTION_RESOURCE_TYPE
    namespace="AWS/VPN"
    dimensions={
        "VpnId" : {
            "Output" : {
                "Attribute" : REFERENCE_ATTRIBUTE_TYPE
            }
        }
    }
/]

[@addCWMetricAttributes
    resourceType=AWS_VPNGATEWAY_VPN_CONNECTION_TUNNEL_RESOURCE_TYPE
    namespace="AWS/VPN"
    dimensions={
        "VpnId" : {
            "OtherOutput" : {
                "Id" : "vpnConnection",
                "Property" : REFERENCE_ATTRIBUTE_TYPE
            }
        },
        "TunnelIpAddress" : {
            "Output" : {
                "Attribute" : IP_ADDRESS_ATTRIBUTE_TYPE,
                "MustExist" : true
            }
        }
    }
/]

[#macro createVPNCustomerGateway
            id
            custSideAsn
            custVPNIP
            tags
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
        tags=tags
    /]
[/#macro]

[#macro createVPNVirtualGateway
            id
            bgpEnabled
            amznSideAsn=""
            tags={}
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
        tags=tags
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
            staticRoutesOnly
            customerGateway
            preSharedKey=""
            transitGateway=""
            vpnGateway=""
            tags={}
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
        tags=tags
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

[#function getVPNTunnelOptionsCli securityProfile tunnelInsideCidr ]

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

    [#local startupAction = ((securityProfile.StartupAction)!"")?lower_case]

    [#return
        {
            "TunnelOptions": {
                "RekeyMarginTimeSeconds": securityProfile.Rekey.MarginTime,
                "RekeyFuzzPercentage": securityProfile.Rekey.FuzzPercentage,
                "ReplayWindowSize": securityProfile.ReplayWindowSize,
                "IKEVersions": ikeVersions,

                "DPDTimeoutSeconds": securityProfile.DeadPeerDetectionTimeout,
                "DPDTimeoutAction" : securityProfile.DeadPeerDetectionAction,

                "Phase1LifetimeSeconds": securityProfile.Phase1.Lifetime,
                "Phase1EncryptionAlgorithms": phase1EncryptionAlgorithms,
                "Phase1IntegrityAlgorithms": phase1IntegrityAlgorithms,
                "Phase1DHGroupNumbers": phase1DHGroupNumbers,

                "Phase2LifetimeSeconds": securityProfile.Phase2.Lifetime,
                "Phase2EncryptionAlgorithms": phase2EncryptionAlgorithms,
                "Phase2IntegrityAlgorithms": phase2IntegrityAlgorithms,
                "Phase2DHGroupNumbers": phase2DHGroupNumbers
            } +
            attributeIfContent(
                "TunnelInsideCidr",
                tunnelInsideCidr
            ) +
            attributeIfContent(
                "StartupAction",
                startupAction
            )
        }
    ]
[/#function]
