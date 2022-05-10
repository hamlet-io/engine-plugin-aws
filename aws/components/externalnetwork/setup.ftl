[#ftl]
[#macro aws_externalnetwork_cf_deployment_generationcontract_segment occurrence ]
    [@addDefaultGenerationContract subsets=[ "template", "cli", "epilogue" ] /]
[/#macro]

[#macro aws_externalnetwork_cf_deployment_segment occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local parentCore = occurrence.Core ]
    [#local parentSolution = occurrence.Configuration.Solution ]
    [#local parentResources = occurrence.State.Resources ]

    [#local BGPASN = parentSolution.BGP.ASN ]

    [#list (occurrence.Occurrences![])?filter(x -> x.Configuration.Solution.Enabled ) as subOccurrence]

        [@debug message="Suboccurrence" context=subOccurrence enabled=false /]

        [#local core = subOccurrence.Core ]
        [#local solution = subOccurrence.Configuration.Solution ]
        [#local resources = subOccurrence.State.Resources ]

        [#if !solution.Enabled ]
            [#continue]
        [/#if]

        [#list (solution.Alerts?values)?filter(x -> x.Enabled) as alert ]

            [#local monitoredResources = getCWMonitoredResources(core.Id, resources, alert.Resource)]
            [#list monitoredResources as name,monitoredResource ]

                [@debug message="Monitored resource" context=monitoredResource enabled=false /]

                [#switch alert.Comparison ]
                    [#case "Threshold" ]
                        [@createAlarm
                            id=formatDependentAlarmId(monitoredResource.Id, alert.Id )
                            severity=alert.Severity
                            resourceName=core.FullName
                            alertName=alert.Name
                            actions=getCWAlertActions(occurrence, solution.Profiles.Alert, alert.Severity )
                            metric=getCWMetricName(alert.Metric, monitoredResource.Type, core.ShortFullName)
                            namespace=getCWResourceMetricNamespace(monitoredResource.Type, alert.Namespace)
                            description=alert.Description!alert.Name
                            threshold=alert.Threshold
                            statistic=alert.Statistic
                            evaluationPeriods=alert.Periods
                            period=alert.Time
                            operator=alert.Operator
                            reportOK=alert.ReportOk
                            unit=alert.Unit
                            missingData=alert.MissingData
                            dimensions=getCWMetricDimensions(alert, monitoredResource, resources)
                        /]
                    [#break]
                [/#switch]
            [/#list]
        [/#list]


        [#switch solution.Engine ]
            [#case "SiteToSite" ]
                [#local customerGatewayId = resources["customerGateway"].Id ]
                [#local customerGatewayName = resources["customerGateway"].Name ]

                [#local vpnPublicIP = (solution.SiteToSite.PublicIP)!"" ]

                [#local vpnOptionsCommand = "vpnOptions"]]
                [#local vpnSecurityProfile = getSecurityProfile(subOccurrence, core.Type, "IPSecVPN")]

                [#if ! vpnPublicIP?has_content ]
                    [@fatal
                        message="VPN Public IP Address not found"
                        context={ "SiteToSite" : solution.SiteToSite }
                    /]
                [/#if]

                [#if deploymentSubsetRequired(EXTERNALNETWORK_COMPONENT_TYPE, true)]
                    [@createVPNCustomerGateway
                        id=customerGatewayId
                        name=customerGatewayName
                        custSideAsn=BGPASN
                        custVPNIP=vpnPublicIP
                    /]
                [/#if]
                [#break]
        [/#switch]

        [#list solution.Links as id,link]
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
                    [#case NETWORK_ROUTER_COMPONENT_TYPE ]

                        [#switch solution.Engine ]
                            [#case "SiteToSite" ]

                                [#local vpnConnectionId = resources["VpnConnections"][id]["vpnConnection"].Id ]
                                [#local vpnConnectionName = resources["VpnConnections"][id]["vpnConnection"].Name ]

                                [#local vpnConnectionTunnel1Id = resources["VpnConnections"][id]["vpnTunnel1"].Id ]
                                [#local vpnConnectionTunnel2Id = resources["VpnConnections"][id]["vpnTunnel2"].Id ]

                                [#local transitGateway = getReference( linkTargetResources["transitGateway"].Id ) ]
                                [#local transitGatewayRouteTableId = linkTargetResources["routeTable"].Id  ]
                                [#local transitGatewayRouteTable = getReference( transitGatewayRouteTableId )]
                                [#local transGatewayAttachmentId =  formatId(vpnConnectionId, "attach") ]


                                [#local externalNetworkCIDRs = getGroupCIDRs(parentSolution.IPAddressGroups, true, occurrence)]


                                [#if deploymentSubsetRequired(EXTERNALNETWORK_COMPONENT_TYPE, true)]
                                    [@createVPNConnection
                                        id=vpnConnectionId
                                        name=vpnConnectionName
                                        staticRoutesOnly=( ! parentSolution.BGP.Enabled )
                                        customerGateway=getReference(customerGatewayId)
                                        transitGateway=transitGateway
                                    /]
                                [/#if]

                                [#if deploymentSubsetRequired("cli", false) ]
                                    [@addCliToDefaultJsonOutput
                                        id=vpnConnectionTunnel1Id
                                        command=vpnOptionsCommand
                                        content=getVPNTunnelOptionsCli(
                                            vpnSecurityProfile,
                                            ((solution.SiteToSite.InsideTunnelCIDRs)![])[0]
                                        )
                                    /]

                                    [@addCliToDefaultJsonOutput
                                        id=vpnConnectionTunnel2Id
                                        command=vpnOptionsCommand
                                        content=getVPNTunnelOptionsCli(
                                            vpnSecurityProfile,
                                            ((solution.SiteToSite.InsideTunnelCIDRs)![])[1]
                                        )
                                    /]
                                [/#if]

                                [#if deploymentSubsetRequired("epilogue", false)]
                                    [@addToDefaultBashScriptOutput
                                        content=
                                            [
                                                r'case ${STACK_OPERATION} in',
                                                r'  create|update)',
                                                r'       # Get cli config file',
                                                r'       split_cli_file "${CLI}" "${tmpdir}" || return $?',
                                                r'       # Create Data pipeline',
                                                r'       info "Applying cli level configurtion"',
                                                r'       update_vpn_options ' +
                                                r'       "' + getRegion() + r'" ' +
                                                r'       "${STACK_NAME}"' +
                                                r'       "' + vpnConnectionId + r'" ' +
                                                r'       "0"' +
                                                r'       "${tmpdir}/cli-' +
                                                            vpnConnectionTunnel1Id + "-" + vpnOptionsCommand + r'.json" || return $?',
                                                r'       update_vpn_options ' +
                                                r'       "' + getRegion() + r'" ' +
                                                r'       "${STACK_NAME}"' +
                                                r'       "' + vpnConnectionId + r'" ' +
                                                r'       "1"' +
                                                r'       "${tmpdir}/cli-' +
                                                            vpnConnectionTunnel2Id + "-" + vpnOptionsCommand + r'.json" || return $?',
                                                r'      tunnel_ips=($(get_vpn_connection_tunnel_ips ' +
                                                r'       "' + getRegion() + r'" ' +
                                                r'       "${STACK_NAME}"' +
                                                r'       "' + vpnConnectionId + r'" ))',
                                                r'      tunnel_ip_1="${tunnel_ips[0]}"',
                                                r'      tunnel_ip_2="${tunnel_ips[1]}"'
                                            ] +
                                                pseudoStackOutputScript(
                                                        "Tunnel IP Addresses",
                                                        {
                                                            formatId(vpnConnectionTunnel1Id, IP_ADDRESS_ATTRIBUTE_TYPE) : "$\{tunnel_ip_1}",
                                                            formatId(vpnConnectionTunnel2Id, IP_ADDRESS_ATTRIBUTE_TYPE) : "$\{tunnel_ip_2}"
                                                        },
                                                        vpnConnectionId
                                                ) +
                                            [
                                                r'       ;;',
                                                r' esac'
                                            ]
                                    /]
                                [/#if]


                                [#if getExistingReference(transGatewayAttachmentId)?has_content ]

                                    [#if deploymentSubsetRequired(EXTERNALNETWORK_COMPONENT_TYPE, true)]
                                        [@createTransitGatewayRouteTableAssociation
                                                id=formatResourceId(
                                                    AWS_TRANSITGATEWAY_ATTACHMENT_RESOURCE_TYPE,
                                                    core.Id,
                                                    linkTargetCore.Id
                                                )
                                                transitGatewayAttachment=getExistingReference(transGatewayAttachmentId)
                                                transitGatewayRouteTable=transitGatewayRouteTable
                                        /]
                                    [/#if]

                                    [#if parentSolution.BGP.Enabled ]

                                        [#if deploymentSubsetRequired(EXTERNALNETWORK_COMPONENT_TYPE, true)]
                                            [@createTransitGatewayRouteTablePropagation
                                                    id=formatResourceId(
                                                        AWS_TRANSITGATEWAY_ROUTETABLE_PROPOGATION_TYPE,
                                                        core.Id,
                                                        linkTargetCore.Id
                                                    )
                                                    transitGatewayAttachment=getExistingReference(transGatewayAttachmentId)
                                                    transitGatewayRouteTable=transitGatewayRouteTable
                                            /]
                                        [/#if]
                                    [#else]
                                        [#list externalNetworkCIDRs as externalNetworkCIDR ]
                                            [#local vpnRouteId = formatResourceId(
                                                    AWS_TRANSITGATEWAY_ROUTE_RESOURCE_TYPE,
                                                    transitGatewayRouteTableId,
                                                    replaceAlphaNumericOnly(externalNetworkCIDR)
                                            )]

                                            [#if deploymentSubsetRequired(EXTERNALNETWORK_COMPONENT_TYPE, true)]
                                                [@createTransitGatewayRoute
                                                        id=vpnRouteId
                                                        transitGatewayRouteTable=transitGatewayRouteTable
                                                        transitGatewayAttachment=getExistingReference(transGatewayAttachmentId)
                                                        destinationCidr=externalNetworkCIDR
                                                /]
                                            [/#if]
                                        [/#list]
                                    [/#if]

                                [#else]

                                    [#if deploymentSubsetRequired("epilogue", false) ]
                                        [@addToDefaultBashScriptOutput
                                            content=[
                                                r'warning "Please run another update to the gateway to create routes"'
                                            ]
                                        /]
                                    [/#if]
                                [/#if]

                                [#if deploymentSubsetRequired("epilogue", false) ]
                                    [@addToDefaultBashScriptOutput
                                        content=[
                                            r'transitGatewayAttachment="$(get_transitgateway_vpn_attachment' +
                                            r' "' + getRegion() + r'" ' +
                                            r' "${STACK_NAME}"' +
                                            r' "' + vpnConnectionId + r'" )"'
                                        ] +
                                        pseudoStackOutputScript(
                                            "VPN Gateway Attachment",
                                            {
                                               transGatewayAttachmentId : r'${transitGatewayAttachment}'
                                            },
                                            vpnConnectionId
                                        )
                                    /]
                                [/#if]
                                [#break]
                        [/#switch]
                        [#break]
                [/#switch]
            [/#if]
        [/#list]
    [/#list]
[/#macro]
