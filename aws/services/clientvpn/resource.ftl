[#ftl]

[#assign AWS_CLIENTVPN_ENDPOINT_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[#assign AWS_CLIENTVPN_NETWORK_ASSOCIATION_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[#assign vpnClientOutputMappings =
    {
        AWS_CLIENTVPN_ENDPOINT_RESOURCE_TYPE : AWS_CLIENTVPN_ENDPOINT_OUTPUT_MAPPINGS,
        AWS_CLIENTVPN_NETWORK_ASSOCIATION_RESOURCE_TYPE : AWS_CLIENTVPN_NETWORK_ASSOCIATION_OUTPUT_MAPPINGS,
        AWS_CLIENTVPN_AUTHORIZATION_RULE_RESOURCE_TYPE : {},
        AWS_CLIENTVPN_ROUTE_RESOURCE_TYPE: {}
    }
]

[#list vpnClientOutputMappings as type, mappings]
    [@addOutputMapping
        provider=AWS_PROVIDER
        resourceType=type
        mappings=mappings
    /]
[/#list]

[#function getClientVPNAuthenticationOption
            type
            directoryId=""
            samlProviderId=""
            samlSelfServiceProviderId=""
            acmRootCACertificateId="" ]

    [#switch type?lower_case ]
        [#case "directory"]
        [#case "directory-service-authentication" ]
            [#local type = "directory-service-authentication" ]
            [#break]

        [#case "externalidp"]
        [#case "federated-authentication"]
            [#local type = "federated-authentication"]
            [#break]

        [#case "mutualtls"]
        [#case "certificate-authentication"]
            [#local type = "certificate-authentication" ]
            [#break]

        [#default]
            [@fatal
                message="Invalid ClientVPN Authentication type"
                context=type
            /]
    [/#switch]

    [#return
        [
            {
                "Type" : type
            } +
            attributeIfTrue(
                "ActiveDirectory",
                type == "directory-service-authentication",
                {
                    "DirectoryId" : getReference(directoryId)
                }
            ) +
            attributeIfTrue(
                "FederatedAuthentication",
                type == "federated-authentication",
                {
                    "SAMLProviderArn" : getReference(samlProviderId, ARN_ATTRIBUTE_TYPE)
                } +
                attributeIfContent(
                    "SelfServiceSAMLProviderArn",
                    samlSelfServiceProviderId,
                    getReference(samlSelfServiceProviderId, ARN_ATTRIBUTE_TYPE)
                )
            ) +
            attributeIfTrue(
                "MutualAuthentication",
                type == "certificate-authentication",
                {
                    "ClientRootCertificateChainArn" : getReference(acmRootCACertificateId, ARN_ATTRIBUTE_TYPE)
                }
            )
        ]
    ]
[/#function]


[#macro createClientVPNEndpoint id name
    tags
    authenticationOptions
    clientCidrBlock
    connectionLogging
    selfServicePortal
    splitTunnel
    certificateId
    lgId
    lgStreamId
    vpcId
    port
    dnsServers=[]
    dependencies=""
    outputId=""
]

    [@cfResource
        id=id
        type="AWS::EC2::ClientVpnEndpoint"
        properties={
            "AuthenticationOptions" : authenticationOptions,
            "ClientCidrBlock" : clientCidrBlock,
            "SelfServicePortal" : selfServicePortal,
            "ServerCertificateArn" : getReference(certificateId, ARN_ATTRIBUTE_TYPE),
            "SplitTunnel" : splitTunnel,
            "TransportProtocol" : port.IPProtocol,
            "VpnPort": port.Port,
            "VpcId" : getReference(vpcId),
            "TagSpecifications" : [
                {
                    "ResourceType" : "client-vpn-endpoint",
                    "Tags" : tags
                }
            ],
            "ConnectionLogOptions" : {
                "Enabled" : connectionLogging
            } +
            attributeIfTrue(
                "CloudwatchLogGroup",
                connectionLogging,
                getReference(lgId)
            ) +
            attributeIfTrue(
                "CloudwatchLogStream",
                connectionLogging,
                getReference(lgStreamId)
            )
        } +
        attributeIfContent(
            "DnsServers",
            dnsServers
        ) +
        attributeIfContent(
            "SecurityGroupIds",
            getReferences
        )
        outputs=AWS_CLIENTVPN_ENDPOINT_OUTPUT_MAPPINGS
        outputId=outputId
        dependencies=dependencies
    /]
[/#macro]



[#macro createClientVPNAuthorizationRule id name
    vpnClientId
    targetCIDR
    groupCondition
    groupName=""
    dependencies=""
    outputId="" ]

    [#local groupConfiguration = {}]
    [#switch groupCondition?lower_case ]
        [#case "allclients" ]
            [#local groupConfiguration = {
                "AuthorizeAllGroups" : true
            }]
            [#break]

        [#case "group"]
            [#local groupConfiguration = {
                "AccessGroupId" : groupName
            }]
            [#break]

        [#default]
            [@fatal
                message="Invalid ClientVPN group condition rule"
                context=groupCondition

            /]
    [/#switch]

    [@cfResource
        id=id
        type="AWS::EC2::ClientVpnAuthorizationRule"
        properties={
            "ClientVpnEndpointId" : getReference(vpnClientId),
            "Description" : name,
            "TargetNetworkCidr" : targetCIDR
        } + groupConfiguration
        outputId=outputId
        dependencies=dependencies
    /]
[/#macro]


[#macro createClientVPNRoute id name
    vpnClientId
    destinationCIDR
    subnetId
    dependencies=""
    outputId="" ]

    [@cfResource
        id=id
        type="AWS::EC2::ClientVpnRoute"
        properties={
            "ClientVpnEndpointId" : getReference(vpnClientId),
            "Description" : name,
            "DestinationCidrBlock" : destinationCIDR,
            "TargetVpcSubnetId" : getReference(subnetId)
        }
        outputId=outputId
        dependencies=dependencies
    /]
[/#macro]


[#macro createClientVPNTargetNetworkAssociation id
    vpnClientId
    subnetId
    dependencies=""
    outputId="" ]

    [@cfResource
        id=id
        type="AWS::EC2::ClientVpnTargetNetworkAssociation"
        properties={
            "ClientVpnEndpointId" : getReference(vpnClientId),
            "SubnetId" : getReference(subnetId)
        }
        outputId=outputId
        dependencies=dependencies
    /]
[/#macro]
