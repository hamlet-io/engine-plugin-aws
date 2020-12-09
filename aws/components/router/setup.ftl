[#ftl]
[#macro aws_router_cf_deployment_generationcontract_segment occurrence ]
    [@addDefaultGenerationContract subsets="template" /]
[/#macro]

[#macro aws_router_cf_deployment_segment occurrence ]
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
            amznSideAsn=BGPConfiguration.ASN
            ecmpSupport=BGPConfiguration.ECMP
        /]

        [@createTransitGatewayRouteTable
            id=routeTableId
            name=routeTableName
            transitGateway=getReference(AWS_PROVIDER, transitGatewayId)
        /]

        [#if solution["aws:ResourceSharing"].Enabled ]

            [#local resourceShareId = resources["resourceShare"].Id ]
            [#local resourceShareName = resources["resourceShare"].Name ]

            [#local transitGatewayArn = formatRegionalArn(
                "ec2",
                {
                    "Fn::Join": [
                        "/",
                        [
                            "transit-gateway",
                            getReference(AWS_PROVIDER, transitGatewayId)
                        ]
                    ]
                }
                )]

            [@createResourceAccessShare
                id=resourceShareId
                name=resourceShareName
                allowNonOrgPrincipals=solution["aws:ResourceSharing"].AllowExternalPrincipals
                principals=solution["aws:ResourceSharing"].AccountPrincipals
                resourceArns=[ transitGatewayArn ]
            /]
        [/#if]
    [/#if]

    [#list occurrence.Occurrences![] as subOccurrence]

        [#local core = subOccurrence.Core ]
        [#local solution = subOccurrence.Configuration.Solution ]
        [#local resources = subOccurrence.State.Resources ]

        [#local destinationCidrs = getGroupCIDRs(solution.IPAddressGroups, true, occurrence)]

        [#switch solution.Action ]
            [#case "forward" ]
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
                            [#case EXTERNALSERVICE_COMPONENT_TYPE ]

                                [#local transitGatewayAttachment = (linkTargetAttributes["TRANSIT_GATEWAY_ATTACHMENT"])!""]

                                [#if ! transitGatewayAttachment?has_content ]
                                    [#if deploymentSubsetRequired(NETWORK_ROUTER_COMPONENT_TYPE, true)]
                                        [@fatal
                                            message="Could not find transit Gateway Attachment Id"
                                            detail="Add setting TRANSIT_GATEWAY_ATTACHMENT as the transit gateawy attachment for the route"
                                            enabled=false
                                        /]
                                    [/#if]
                                [/#if]

                                [#local routeTableAssociationId = resources["routeAssociations"][linkTargetCore.Id].Id]

                                [#if deploymentSubsetRequired(NETWORK_ROUTER_COMPONENT_TYPE, true)]
                                [@createTransitGatewayRouteTableAssociation
                                    id=routeTableAssociationId
                                    transitGatewayAttachment=transitGatewayAttachment
                                    transitGatewayRouteTable=getReference(AWS_PROVIDER, routeTableId)
                                /]
                                [/#if]

                                [#list destinationCidrs as destinationCidr ]
                                    [#local destinationCidrId = replaceAlphaNumericOnly(destinationCidr)]
                                    [#local routeId = resources["routes"][linkTargetCore.Id][destinationCidrId].Id ]

                                    [#if deploymentSubsetRequired(NETWORK_ROUTER_COMPONENT_TYPE, true)]
                                        [@createTransitGatewayRoute
                                                id=routeId
                                                transitGatewayRouteTable=getReference(AWS_PROVIDER, routeTableId)
                                                transitGatewayAttachment=transitGatewayAttachment
                                                destinationCidr=destinationCidr
                                        /]
                                    [/#if]
                                [/#list]
                                [#break]
                        [/#switch]
                    [/#if]
                [/#list]
                [#break]

            [#case "blackhole" ]
                [#list destinationCidrs as destinationCidr ]
                    [#local destinationCidrId = replaceAlphaNumericOnly(destinationCidr)]
                    [#local routeId = resources["routes"][destinationCidrId].Id ]

                    [#if deploymentSubsetRequired(NETWORK_ROUTER_COMPONENT_TYPE, true)]
                        [@createTransitGatewayRoute
                                id=routeId
                                transitGatewayRouteTable=getReference(AWS_PROVIDER, routeTableId)
                                blackhole=true
                                destinationCidr=destinationCidr
                        /]
                    [/#if]
                [/#list]
                [#break]
        [/#switch]
    [/#list]
[/#macro]
