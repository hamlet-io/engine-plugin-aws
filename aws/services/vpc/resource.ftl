[#ftl]

[#function getSecurityGroupPortRule port ]
    [#if port?is_string &&
            ( ((ports[port].IPProtocol)!"") == "all")  ]

            [#return {
                "IpProtocol" : "-1"
            }]

    [#else]
        [#return
            port?is_number?then(
            (port == 0)?then(
                {
                    "IpProtocol": "tcp",
                    "FromPort": 32768,
                    "ToPort" : 65535
                },
                {
                    "IpProtocol": "tcp",
                    "FromPort": port,
                    "ToPort" : port
                }
            ),
            {
                "IpProtocol": ports[port]?has_content?then(
                                    ports[port].IPProtocol,
                                    -1
                                ),

                "FromPort": ports[port]?has_content?then(
                                    ports[port].PortRange.Configured?then(
                                            ports[port].PortRange.From,
                                            ports[port].Port
                                    ),
                                    1),

                "ToPort": ports[port]?has_content?then(
                                    ports[port].PortRange.Configured?then(
                                        ports[port].PortRange.To,
                                        ports[port].Port
                                    ),
                                    65535)
            }
        )
        ]
    [/#if]
[/#function]

[#function getSecurityGroupRules port cidrs=[] groups=[] direction="ingress" description="" ]
    [#local rules = [] ]

    [#local baseRule = {} +
        getSecurityGroupPortRule(port) +
        attributeIfContent(
            "Description",
            description
        )]

    [#if groups?has_content ]
        [#list asArray(groups) as group]

            [#local existingGroup = group?starts_with("pl-") || group?starts_with("sg-") ]
            [#switch direction ]
                [#case "ingress" ]

                    [#if existingGroup && group?starts_with("pl-") ]
                        [#local rule =
                            {
                                "SourcePrefixListId" : group
                            }
                        ]
                    [#else]
                        [#local rule =
                            {
                                "SourceSecurityGroupId" : existingGroup?then(
                                                                group,
                                                                getReference(group)
                                                            )
                            }
                        ]
                    [/#if]
                    [#break]

                [#case "egress" ]
                    [#if existingGroup && group?starts_with("pl-") ]
                        [#local rule =
                            {
                                "DestinationPrefixListId" : group
                            }
                        ]
                    [#else]
                        [#local rule =
                            {
                                "DestinationSecurityGroupId" : existingGroup?then(
                                                                    group,
                                                                    getReference(group)
                                                                )
                            }]
                    [/#if]
                    [#break]
            [/#switch]
            [#local rules += [ mergeObjects(baseRule, rule) ] ]
        [/#list]
    [/#if]

    [#if cidrs?has_content]
        [#list asArray(cidrs) as cidrBlock]
            [#if cidrBlock?contains(":") ]
                [#local rule =
                    {
                        "CidrIpv6": cidrBlock
                    }
                ]
            [#else]
                [#local rule =
                    {
                        "CidrIp": cidrBlock
                    }
                ]
            [/#if]
            [#local rules += [ mergeObjects(baseRule, rule) ] ]
        [/#list]
    [/#if]
    [#return rules]
[/#function]

[#macro createSecurityGroupRulesFromLink occurrence groupId inboundPorts linkTarget networkProfile ]

    [#local linkTargetRoles = linkTarget.State.Roles ]
    [#local linkDirection = linkTarget.Direction ]
    [#local linkRole = linkTarget.Role]
    [#local globalAllow = networkProfile.BaseSecurityGroup.Outbound.GlobalAllow ]

    [#if (linkTargetRoles.Inbound["networkacl"]!{})?has_content
            && linkDirection == "inbound"
            && linkRole == "networkacl"
            && inboundPorts?has_content ]

        [#local linkTargetInboundRule = mergeObjects(
                                        linkTargetRoles.Inbound["networkacl"],
                                        {
                                            "Ports" : inboundPorts
                                        }
                                    )]

        [@createSecurityGroupIngressFromNetworkRule
            occurrence=occurrence
            groupId=groupId
            networkRule=linkTargetInboundRule
        /]
    [/#if]

    [#if (linkTargetRoles.Outbound["networkacl"]!{})?has_content
            && linkTarget.Direction == "outbound"
            && ! globalAllow ]
        [@createSecurityGroupEgressFromNetworkRule
            occurrence=occurrence
            groupId=groupId
            networkRule=linkTargetRoles.Outbound["networkacl"]
        /]
    [/#if]
[/#macro]

[#macro createSecurityGroupRulesFromNetworkProfile occurrence groupId networkProfile inboundPorts ]

    [#if !(networkProfile.BaseSecurityGroup.Outbound.GlobalAllow) ]
        [@createSecurityGroupEgressFromNetworkRule
            occurrence=occurrence
            groupId=groupId
            networkRule={
                "Ports" : [ "any" ],
                "IPAddressGroups" : [ "_localhost" ],
                "Description" : "Explicit outbound base rule"
            }
        /]

        [#list networkProfile.BaseSecurityGroup.Outbound.NetworkRules?values as networkRule ]
            [@createSecurityGroupEgressFromNetworkRule
                occurrence=occurrence
                groupId=groupId
                networkRule=networkRule
            /]
        [/#list]
    [/#if]

    [#list networkProfile.BaseSecurityGroup.Links?values as link]
        [#if link?is_hash]
            [#local linkTarget = getLinkTarget(occurrence, link) ]

            [#if !linkTarget?has_content]
                [#continue]
            [/#if]

            [@createSecurityGroupRulesFromLink
                occurrence=occurrence
                groupId=groupId
                linkTarget=linkTarget
                inboundPorts=inboundPorts
                networkProfile=networkProfile
            /]
        [/#if]
    [/#list]
[/#macro]

[#macro createSecurityGroupIngressFromNetworkRule occurrence groupId networkRule ]

    [#-- validate provide rule against configuration --]
    [#local networkRule = getCompositeObject(getAttributeSet(NETWORKRULE_ATTRIBUTESET_TYPE).Attributes, networkRule) ]
    [#list networkRule.Ports as port ]
        [#if (networkRule.IPAddressGroups)?has_content ]
            [#list (getGroupCIDRs(networkRule.IPAddressGroups, true, occurrence ))?filter(cidr -> cidr?has_content) as cidr ]
                [@createSecurityGroupIngress
                    id=formatDependentSecurityGroupIngressId(groupId, port, replaceAlphaNumericOnly(cidr))
                    groupId=groupId
                    port=port
                    cidr=cidr
                    description=networkRule.Description
                /]
            [/#list]
        [/#if]

        [#if (networkRule.SecurityGroups)?has_content ]
            [#list (networkRule.SecurityGroups)?filter(group -> group?has_content) as securityGroup ]
                [@createSecurityGroupIngress
                    id=formatDependentSecurityGroupIngressId(groupId, port, replaceAlphaNumericOnly(securityGroup))
                    groupId=groupId
                    port=port
                    group=securityGroup
                    description=networkRule.Description
                /]
            [/#list]
        [/#if]
    [/#list]
[/#macro]

[#macro createSecurityGroupIngress id groupId port cidr="" group="" description="" ]
    [@cfResource
        id=id
        type="AWS::EC2::SecurityGroupIngress"
        properties=
            {
                "GroupId" : getReference(groupId)
            } +
            getSecurityGroupRules(port, cidr, group, "ingress", description )[0]
        outputs={}
    /]
[/#macro]

[#macro createSecurityGroupEgressFromNetworkRule occurrence groupId networkRule ]

    [#-- validate provide rule against configuration --]
    [#local networkRule = getCompositeObject(getAttributeSet(NETWORKRULE_ATTRIBUTESET_TYPE).Attributes, networkRule) ]

    [#list networkRule.Ports as port ]
        [#if (networkRule.IPAddressGroups)?has_content ]
            [#list (getGroupCIDRs(networkRule.IPAddressGroups, true, occurrence ))?filter(cidr -> cidr?has_content) as cidr ]
                [@createSecurityGroupEgress
                    id=formatDependentSecurityGroupEgressId(groupId, port, replaceAlphaNumericOnly(cidr))
                    groupId=groupId
                    port=port
                    cidr=cidr
                    description=networkRule.Description
                /]
            [/#list]
        [/#if]

        [#if (networkRule.SecurityGroups)?has_content ]
            [#list (networkRule.SecurityGroups)?filter(group -> group?has_content) as securityGroup ]
                [@createSecurityGroupEgress
                    id=formatDependentSecurityGroupEgressId(groupId, port, replaceAlphaNumericOnly(securityGroup))
                    groupId=groupId
                    port=port
                    group=securityGroup
                    description=networkRule.Description
                /]
            [/#list]
        [/#if]
    [/#list]
[/#macro]

[#macro createSecurityGroupEgress id groupId port cidr="" group="" description="" ]
    [@cfResource
        id=id
        type="AWS::EC2::SecurityGroupEgress"
        properties=
            {
                "GroupId" : groupId?is_string?then(getReference(groupId), groupId)
            } +
            getSecurityGroupRules(port, cidr, group, "egress", description )[0]
        outputs={}
    /]
[/#macro]

[#assign AWS_VPC_SECURITY_GROUP_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE
    mappings=AWS_VPC_SECURITY_GROUP_OUTPUT_MAPPINGS
/]

[#macro createSecurityGroup id name vpcId description="" tags={} ]
    [@cfResource
        id=id
        type="AWS::EC2::SecurityGroup"
        properties=
            {
                "GroupDescription" : description?has_content?then(description, name),
                "VpcId" : (vpcId?has_content)?then(
                                getReference(vpcId),
                                getVpc()
                            )
            }
        tags=tags
        outputs=AWS_VPC_SECURITY_GROUP_OUTPUT_MAPPINGS
    /]

[/#macro]

[#assign AWS_VPC_FLOWLOG_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_VPC_FLOWLOG_RESOURCE_TYPE
    mappings=AWS_VPC_FLOWLOG_OUTPUT_MAPPINGS
/]

[#macro createFlowLog
            id
            roleId
            logDestinationType
            resourceId
            resourceType
            trafficType
            logGroupName=""
            s3BucketId=""
            s3BucketPrefix=""
            tags={} ]

    [#switch logDestinationType?lower_case ]
        [#case "cloudwatch" ]
        [#case "cloud-watch-logs" ]
        [#case "log"]
            [#local logDestinationType = "cloud-watch-logs" ]
            [#break]

        [#case "s3"]
            [#local logDestinationType = "s3"]
            [#break]

        [#default ]
            [@fatal
                message="Unkown FlowLog Log DestinationType"
                context={
                    "id" : id,
                    "Resource" : "AWS::EC2::FlowLog",
                    "logDestinationType" : logDestinationType
                }
            /]
    [/#switch]

    [#switch trafficType?lower_case ]
        [#case "all"]
        [#case "any"]
            [#local trafficType = "ALL" ]
            [#break]

        [#case "reject" ]
            [#local trafficType = "REJECT"]
            [#break]

        [#case "allow" ]
            [#local trafficType = "ALLOW"]
            [#break]
    [/#switch]

    [@cfResource
        id=id
        tags=tags
        type="AWS::EC2::FlowLog"
        properties=
            {
                "ResourceId" : getReference(resourceId),
                "ResourceType" : resourceType,
                "TrafficType" : trafficType?upper_case,
                "LogDestinationType" : logDestinationType
            } +
            ( logDestinationType == "cloud-watch-logs" )?then(
                {
                    "DeliverLogsPermissionArn" : getReference(roleId, ARN_ATTRIBUTE_TYPE),
                    "LogGroupName" : logGroupName
                },
                {}
            ) +
            ( logDestinationType == "s3" )?then(
                {
                    "LogDestination" : {
                        "Fn::Join" : [
                            "/",
                            [
                                getArn(s3BucketId),
                                s3BucketPrefix
                            ]
                        ]
                    }
                },
                {}
            )
        outputs=AWS_VPC_FLOWLOG_OUTPUT_MAPPINGS
    /]
[/#macro]

[#assign VPC_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true,
            "Export" : true
        },
        REGION_ATTRIBUTE_TYPE : {
            "Value" : { "Ref" : "AWS::Region" }
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_VPC_RESOURCE_TYPE
    mappings=VPC_OUTPUT_MAPPINGS
/]

[#macro createVPC
            id
            cidr
            dnsSupport
            dnsHostnames
            resourceId=""
            tags={}]
    [@cfResource
        id=(resourceId?has_content)?then(
                            resourceId,
                            id)
        type="AWS::EC2::VPC"
        properties=
            {
                "CidrBlock" : cidr,
                "EnableDnsSupport" : dnsSupport,
                "EnableDnsHostnames" : dnsHostnames
            }
        tags=tags
        outputs=VPC_OUTPUT_MAPPINGS
        outputId=id
    /]
[/#macro]

[#assign AWS_VPC_IGW_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_VPC_IGW_RESOURCE_TYPE
    mappings=AWS_VPC_IGW_OUTPUT_MAPPINGS
/]

[#macro createIGW
            id
            resourceId=""
            tags={}]
    [@cfResource
        id=(resourceId?has_content)?then(
                            resourceId,
                            id)
        type="AWS::EC2::InternetGateway"
        tags=tags
        outputId=id
        outputs=AWS_VPC_IGW_OUTPUT_MAPPINGS
    /]
[/#macro]

[#macro createIGWAttachment
            id
            vpcId
            igwId]
    [@cfResource
        id=id
        type="AWS::EC2::VPCGatewayAttachment"
        properties=
            {
                "InternetGatewayId" : getReference(igwId),
                "VpcId" : getReference(vpcId)
            }
        outputs={}
    /]
[/#macro]

[#assign EIP_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        IP_ADDRESS_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ALLOCATION_ATTRIBUTE_TYPE : {
            "Attribute" : "AllocationId"
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_EIP_RESOURCE_TYPE
    mappings=EIP_OUTPUT_MAPPINGS
/]

[#macro createEIP
            id
            tags={}
            dependencies=""]
    [@cfResource
        id=id
        type="AWS::EC2::EIP"
        properties=
            {
                "Domain" : "vpc"
            }
        outputs=EIP_OUTPUT_MAPPINGS
        tags=tags
        dependencies=dependencies
    /]
[/#macro]

[#macro createNATGateway
            id,
            tags,
            subnetId,
            eipId]
    [@cfResource
        id=id
        type="AWS::EC2::NatGateway"
        properties=
            {
                "AllocationId" : getReference(eipId, ALLOCATION_ATTRIBUTE_TYPE),
                "SubnetId" : getReference(subnetId)
            }
        tags=tags

    /]
[/#macro]

[#assign AWS_VPC_ROUTE_TABLE_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_VPC_ROUTE_TABLE_RESOURCE_TYPE
    mappings=AWS_VPC_ROUTE_TABLE_OUTPUT_MAPPINGS
/]

[#macro createRouteTable
            id
            vpcId
            tags={}
            dependencies=[]]
    [@cfResource
        id=id
        type="AWS::EC2::RouteTable"
        properties=
            {
                "VpcId" : getReference(vpcId)
            }
        tags=tags
        dependencies=dependencies
    /]
[/#macro]

[#macro createRoute
            id
            routeTableId
            destinationType
            destinationAttribute
            destinationCidr
            dependencies=""]

    [#local properties =
        {
            "RouteTableId" : getReference(routeTableId),
            "DestinationCidrBlock" : destinationCidr
        }
    ]
    [#switch (destinationType)?lower_case ]
        [#case "gateway"]
            [#local properties +=
                {
                    "GatewayId" : destinationAttribute
                }
            ]
            [#break]

        [#case "instance"]
            [#local properties +=
                {
                    "InstanceId" : destinationAttribute
                }
            ]
            [#break]

        [#case "vpcendpoint"]
            [#local properties +=
                {
                    "VpcEndpointId" : destinationAttribute
                }
            ]
            [#break]

        [#case "networkinterface" ]
            [#local properties +=
                {
                    "NetworkInterfaceId" : destinationAttribute
                }
            ]
            [#break]

        [#case "nat"]
            [#local properties +=
                {
                    "NatGatewayId" : destinationAttribute
                }
            ]
            [#break]

        [#case "peering" ]
            [#local properties +=
                {
                    "VpcPeeringConnectionId" : destinationAttribute
                }
            ]
            [#break]

        [#case "transit" ]
            [#local properties +=
                {
                    "TransitGatewayId" : destinationAttribute
                }
            ]
            [#break]


    [/#switch]
    [@cfResource
        id=id
        type="AWS::EC2::Route"
        properties=properties
        outputs={}
        dependencies=dependencies
    /]
[/#macro]

[#assign AWS_VPC_NETWORK_ACL_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_VPC_NETWORK_ACL_RESOURCE_TYPE
    mappings=AWS_VPC_NETWORK_ACL_OUTPUT_MAPPINGS
/]

[#macro createNetworkACL
            id,
            vpcId
            tags={}]
    [@cfResource
        id=id
        type="AWS::EC2::NetworkAcl"
        properties=
            {
                "VpcId" : getReference(vpcId)
            }
        tags=tags
        outputs=AWS_VPC_NETWORK_ACL_OUTPUT_MAPPINGS
    /]
[/#macro]

[#macro createNetworkACLEntry
            id,
            networkACLId,
            outbound,
            rule,
            port]

    [#local protocol = port.IPProtocol]

    [#local fromPort = (port.PortRange.From)?has_content?then(
                            port.PortRange.From,
                            (port.Port)?has_content?then(
                                port.Port,
                                0
                            ))]

    [#local toPort = (port.PortRange.To)?has_content?then(
                            port.PortRange.To,
                            (port.Port)?has_content?then(
                                port.Port,
                                0
                            ))]
    [#switch port.IPProtocol]
        [#case "all"]
            [#local properties =
                {
                    "Protocol" : -1,
                    "PortRange" : {
                        "From" : fromPort,
                        "To" : toPort
                    }
                }
            ]
            [#break]
        [#case "icmp"]
            [#local properties =
                {
                    "Protocol" : 1,
                    "Icmp" : {
                        "Code" : (port.ICMP.Code)!-1,
                        "Type" : (port.ICMP.Type)!-1
                    }
                }
            ]
            [#break]
        [#case "udp"]
            [#local properties =
                {
                    "Protocol" : 17,
                    "PortRange" : {
                        "From" : fromPort,
                        "To" : toPort
                    }
                }
            ]
            [#break]
        [#case "tcp"]
            [#local properties =
                {
                    "Protocol" : 6,
                    "PortRange" : {
                        "From" : fromPort,
                        "To" : toPort
                    }
                }
            ]
            [#break]
    [/#switch]
    [@cfResource
        id=id
        type="AWS::EC2::NetworkAclEntry"
        properties=
            properties +
            {
                "NetworkAclId" : networkACLId?is_string?then(getReference(networkACLId), networkACLId),
                "Egress" : outbound,
                "RuleNumber" : rule.RuleNumber,
                "RuleAction" : rule.Allow?string("allow","deny"),
                "CidrBlock" : rule.CIDRBlock
            }
        outputs={}
    /]
[/#macro]

[#assign AWS_VPC_SUBNET_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_VPC_SUBNET_TYPE
    mappings=AWS_VPC_SUBNET_OUTPUT_MAPPINGS
/]

[#macro createSubnet
            id
            vpcId
            zone
            cidr
            tags={}]

    [@cfResource
        id=id
        type="AWS::EC2::Subnet"
        properties=
            {
                "VpcId" : getReference(vpcId),
                "AvailabilityZone" : getCFAWSAzReference(zone.Id),
                "CidrBlock" : cidr
            }
        tags=tags
        outputs=AWS_VPC_SUBNET_OUTPUT_MAPPINGS
    /]
[/#macro]

[#macro createRouteTableAssociation
            id,
            subnetId,
            routeTableId]

    [@cfResource
        id=id
        type="AWS::EC2::SubnetRouteTableAssociation"
        properties=
            {
                "SubnetId" : getReference(subnetId),
                "RouteTableId" : getReference(routeTableId)
            }
        outputs={}
    /]
[/#macro]

[#macro createRouteTableGatewayAssociation
            id
            gatewayId
            routeTableId
            dependencies=[]]
    [@cfResource
        id=id
        type="AWS::EC2::GatewayRouteTableAssociation"
        properties={
            "GatewayId" : getReference(gatewayId),
            "RouteTableId" : getReference(routeTableId)
        }
        outputs={}
        dependencies=dependencies
    /]
[/#macro]

[#macro createNetworkACLAssociation
            id,
            subnetId,
            networkACLId]

    [@cfResource
        id=id
        type="AWS::EC2::SubnetNetworkAclAssociation"
        properties=
            {
                "SubnetId" : getReference(subnetId),
                "NetworkAclId" : getReference(networkACLId)
            }
        outputs={}
    /]
[/#macro]

[#assign AWS_VPC_VPCENDPOINT_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_VPC_VPCENDPOINT_RESOURCE_TYPE
    mappings=AWS_VPC_VPCENDPOINT_OUTPUT_MAPPINGS
/]

[#macro createVPCEndpoint
            id,
            vpcId,
            service,
            type,
            privateDNSZone=false,
            subnetIds=[],
            routeTableIds=[],
            securityGroupIds=[],
            statements=[]
]

    [@cfResource
        id=id
        type="AWS::EC2::VPCEndpoint"
        properties=
            {
                "ServiceName" : service,
                "VpcId" : getReference(vpcId)
            } +
            (type == "gateway")?then(
                {
                    "VpcEndpointType" : "Gateway",
                    [#-- For manually configured vpcs, the same route table may be used in multiple zones --]
                    "RouteTableIds" : getUniqueArrayElements(getReferences(routeTableIds))
                } +
                valueIfContent(getPolicyDocument(statements), statements),
                {}
            ) +
            (type == "interface")?then(
                {
                    "VpcEndpointType" : "Interface",
                    "SubnetIds" : getReferences(subnetIds),
                    "PrivateDnsEnabled" : privateDNSZone,
                    "SecurityGroupIds" : getReferences(securityGroupIds)
                } +
                valueIfContent(getPolicyDocument(statements), statements),
                {}
            )
        outputs=AWS_VPC_VPCENDPOINT_OUTPUT_MAPPINGS
    /]
[/#macro]

[#assign AWS_VPC_ENDPOINT_SERVICE_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_VPC_ENDPOINT_SERVICE_RESOURCE_TYPE
    mappings=AWS_VPC_ENDPOINT_SERVICE_OUTPUT_MAPPINGS
/]

[#macro createVPCEndpointService
    id
    loadBalancerIds
    acceptanceRequired
    dependencies=""
]

    [@cfResource
        id=id
        type="AWS::EC2::VPCEndpointService"
        properties={
            "AcceptanceRequired" : acceptanceRequired,
            "NetworkLoadBalancerArns" : getReferences(loadBalancerIds, ARN_ATTRIBUTE_TYPE)
        }
        dependencies=dependencies
        outputs=AWS_VPC_ENDPOINT_SERVICE_OUTPUT_MAPPINGS
    /]
[/#macro]

[#macro createVPCEndpointServicePermission
    id
    vpcEndpointServiceId
    principalArns=[]
    dependencies=""
]
    [@cfResource
        id=id
        type="AWS::EC2::VPCEndpointServicePermissions"
        properties={
            "ServiceId" : getReference(vpcEndpointServiceId),
            "AllowedPrincipals" : principalArns
        }
        dependencies=dependencies
    /]
[/#macro]

[#macro createVPCEndpointServiceNotification
    id
    events
    notificationEndpointId
    vpcEndpointServiceId=""
    vpcEndpointId=""
    dependencies=""
]
    [@cfResource
        id=id
        type="AWS::EC2::VPCEndpointConnectionNotification"
        properties={
            "ConnectionEvents" : asArray(events),
            "ConnectionNotificationArn" : getArn(notificationEndpointId)
        } +
        attributeIfContent(
            "ServiceId",
            vpcEndpointServiceId,
            getReference(vpcEndpointServiceId)
        ) +
        attributeIfContent(
            "VPCEndpointId",
            vpcEndpointId,
            getReference(vpcEndpointId)
        )
        dependencies=dependencies
    /]
[/#macro]
