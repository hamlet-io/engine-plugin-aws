[#ftl]
[#macro aws_network_cf_deployment_generationcontract_segment occurrence ]
    [@addDefaultGenerationContract subsets=["deploymentcontract", "template"] /]
[/#macro]

[#macro aws_network_cf_deployment_deploymentcontract occurrence ]
    [@addDefaultAWSDeploymentContract /]
[/#macro]

[#macro aws_network_cf_deployment_segment occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]

    [#local vpcId = resources["vpc"].Id]
    [#local vpcResourceId = resources["vpc"].ResourceId]
    [#local vpcName = resources["vpc"].Name]
    [#local vpcCIDR = resources["vpc"].Address]

    [#local defaultSecurityGroup = resources["defaultSecurityGroup"] ]
    [#local defaultNetworkACL = resources["defaultNetworkACL"] ]

    [#local dnsSupport = (network.DNSSupport)!solution.DNS.UseProvider ]
    [#local dnsHostnames = (network.DNSHostnames)!solution.DNS.GenerateHostNames ]

    [#local loggingProfile = getLoggingProfile(occurrence)]
    [#local networkProfile = getNetworkProfile(occurrence)]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "Encryption" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local kmsKeyId = baselineComponentIds["Encryption"] ]

    [#-- Flag that the flowlog configuration needs to be updated if enabled via flags --]
    [#if deploymentSubsetRequired(NETWORK_COMPONENT_TYPE, true) &&
        (
            (environmentObject.Operations.FlowLogs.Enabled)!
            (segmentObject.Operations.FlowLogs.Enabled)!
            (solution.Logging.EnableFlowLogs)!false
        ) &&
        !(resources["flowLogs"]?has_content) ]
        [@fatal
            message="Flowlogs must now be explicitly configured on the network component"
        /]
    [/#if]

    [#list resources["flowLogs"]!{} as  id, flowLogResource ]
        [#local flowLogId = flowLogResource["flowLog"].Id ]
        [#local flowLogName = flowLogResource["flowLog"].Name ]

        [#local flowLogRoleId = (flowLogResource["flowLogRole"].Id)!"" ]
        [#local flowLogLogGroupId = (flowLogResource["flowLogLg"].Id)!"" ]
        [#local flowLogLogGroupName = (flowLogResource["flowLogLg"].Name)!"" ]

        [#local flowLogSolution = solution.Logging.FlowLogs[id] ]
        [#local flowLogDestinationType = flowLogSolution.DestinationType ]

        [#local flowLogS3DestinationArn = "" ]

        [#local flowLogS3DestinationPrefix =
                    formatRelativePath(
                        (flowLogSolution.s3.IncludeInPrefix)?map(
                            x -> (x == "Prefix")?then(
                                flowLogSolution.s3.Prefix,
                                (x == "FullAbsolutePath" )?then(
                                    core.FullAbsolutePath,
                                    (x == "Id" )?then(
                                        id,
                                        ""
                                    )
                                )
                            )
                        )
                    )]

        [#if flowLogDestinationType == "log" ]
            [#if deploymentSubsetRequired("iam", true) &&
                    isPartOfCurrentDeploymentUnit(flowLogRoleId)]
                [@createRole
                    id=flowLogRoleId
                    trustedServices=["vpc-flow-logs.amazonaws.com"]
                    policies=
                        [
                            getPolicyDocument(
                                cwLogsProducePermission(flowLogLogGroupName),
                                "flow-logs-cloudwatch")
                        ]
                    tags=getOccurrenceTags(occurrence)
                /]
            [/#if]

            [@setupLogGroup
                occurrence=occurrence
                logGroupId=flowLogLogGroupId
                logGroupName=flowLogLogGroupName
                loggingProfile=loggingProfile
                kmsKeyId=kmsKeyId
                retention=((segmentObject.Operations.FlowLogs.Expiration) !
                                (segmentObject.Operations.Expiration) !
                                (environmentObject.Operations.FlowLogs.Expiration) !
                                (environmentObject.Operations.Expiration) ! 7)
            /]
        [/#if]

        [#if flowLogDestinationType = "s3" ]
            [#local destinationLink = getLinkTarget(occurrence, flowLogSolution.s3.Link) ]

            [#if destinationLink?has_content ]
                [#switch destinationLink.Core.Type ]
                    [#case S3_COMPONENT_TYPE]
                    [#case BASELINE_DATA_COMPONENT_TYPE]
                        [#local flowLogS3DestinationArn = (destinationLink.State.Attributes["ARN"])!"" ]
                        [#break]

                    [#default]
                        [@fatal
                            message="Invalid S3 Flow log destination component type"
                            context={
                                "Id" : flowLogsId,
                                "Link" : flowLogSolution.s3.Link
                            }
                        /]
                [/#switch]
            [/#if]
        [/#if]

        [#if deploymentSubsetRequired(NETWORK_COMPONENT_TYPE, true)]
            [@createFlowLog
                id=flowLogId
                logDestinationType=flowLogSolution.DestinationType
                resourceId=vpcResourceId
                resourceType="VPC"
                roleId=flowLogRoleId
                logGroupName=flowLogLogGroupName
                s3BucketId=flowLogS3DestinationArn
                s3BucketPrefix=flowLogS3DestinationPrefix
                trafficType=flowLogSolution.Action
                tags=getOccurrenceTags(
                        occurrence,
                        {},
                        ["flowlog", id]
                    )
            /]
        [/#if]
    [/#list]

    [#list resources["dnsQueryLoggers"]!{} as  id, dnsQueryLogger ]
        [#local dnsQueryLoggerId = dnsQueryLogger["dnsQueryLogger"].Id ]
        [#local dnsQueryLoggerName = dnsQueryLogger["dnsQueryLogger"].Name ]

        [#local dnsQueryLoggerAssocId = dnsQueryLogger["dnsQueryLoggerAssoc"].Id ]

        [#local dnsQueryLogGroupId = (dnsQueryLogger["dnsQueryLg"].Id)!"" ]
        [#local dnsQueryLogGroupName = (dnsQueryLogger["dnsQueryLg"].Name)!"" ]

        [#local dnsQueryLoggerSolution = solution.Logging.DNSQuery[id] ]
        [#local dnsQueryLoggerDestinationType = dnsQueryLoggerSolution.DestinationType ]

        [#local destinationArn = "" ]

        [#if dnsQueryLoggerDestinationType == "log" ]
            [@setupLogGroup
                occurrence=occurrence
                logGroupId=dnsQueryLogGroupId
                logGroupName=dnsQueryLogGroupName
                loggingProfile=loggingProfile
                kmsKeyId=kmsKeyId
            /]

            [#local destinationArn = dnsQueryLogGroupId ]
        [/#if]

        [#if dnsQueryLoggerDestinationType == "s3" || dnsQueryLoggerDestinationType == "datafeed" ]

            [#switch dnsQueryLoggerDestinationType ]
                [#case "s3" ]
                    [#local linkSolution = flowLogSolution.s3.Link]
                    [#break]

                [#case "datafeed"]
                    [#local linkSolution = flowLogSolution.datafeed.Link]
                    [#break]
            [/#switch]

            [#local destinationLink = getLinkTarget(occurrence, linkSolution) ]
            [#if destinationLink?has_content ]
                [#switch destinationLink.Core.Type ]
                    [#case S3_COMPONENT_TYPE]
                    [#case BASELINE_DATA_COMPONENT_TYPE]
                    [#case DATAFEED_COMPONENT_TYPE]
                        [#local destinationArn = (destinationLink.State.Attributes["ARN"])!"" ]
                        [#break]

                    [#default]
                        [@fatal
                            message="Invalid DNS Query log destination component type"
                            context={
                                "Id" : flowLogsId,
                                "Link" : linkSolution
                            }
                        /]
                [/#switch]
            [/#if]
        [/#if]

        [#if deploymentSubsetRequired(NETWORK_COMPONENT_TYPE, true)]
            [@createRoute53ResolverLogging
                id=dnsQueryLoggerId
                name=dnsQueryLoggerName
                destinationId=destinationArn
            /]

            [@createRoute53ResolverLoggingAssociation
                id=dnsQueryLoggerAssocId
                resolverLoggingId=dnsQueryLoggerId
                vpcId=vpcResourceId
            /]
        [/#if]
    [/#list]

    [#if deploymentSubsetRequired(NETWORK_COMPONENT_TYPE, true)]
        [@createVPC
            id=vpcId
            resourceId=vpcResourceId
            cidr=vpcCIDR
            dnsSupport=dnsSupport
            dnsHostnames=dnsHostnames
            tags=getOccurrenceTags(occurrence)
        /]

        [#-- Catch the Default groups so we can reference them --]
        [@cfOutput
            formatId(defaultSecurityGroup.Id, REFERENCE_ATTRIBUTE_TYPE),
            {
                "Fn::GetAtt": [
                    vpcResourceId,
                    "DefaultSecurityGroup"
                ]
            }
        /]

        [@cfOutput
            formatId(defaultNetworkACL.Id, REFERENCE_ATTRIBUTE_TYPE),
            {
                "Fn::GetAtt": [
                    vpcResourceId,
                    "DefaultNetworkAcl"
                ]
            }
        /]

        [@createSecurityGroupRulesFromNetworkProfile
            occurrence=occurrence
            groupId={
                "Fn::GetAtt": [
                    vpcResourceId,
                    "DefaultSecurityGroup"
                ]
            }
            networkProfile=networkProfile
            inboundPorts=[]
        /]

    [/#if]

    [#local legacyIGWId = "" ]
    [#local legacyIGWResourceId = ""]
    [#if (resources["legacyIGW"]!{})?has_content]
        [#local legacyIGWId = resources["legacyIGW"].Id ]
        [#local legacyIGWResourceId = resources["legacyIGW"].ResourceId]
        [#local legacyIGWName = resources["legacyIGW"].Name]
        [#local legacyIGWAttachmentId = resources["legacyIGWAttachment"].Id ]

        [#if deploymentSubsetRequired(NETWORK_COMPONENT_TYPE, true)]
            [@createIGW
                id=legacyIGWId
                resourceId=legacyIGWResourceId
                tags=getOccurrenceTags(occurrence)
            /]
            [@createIGWAttachment
                id=legacyIGWAttachmentId
                vpcId=vpcResourceId
                igwId=legacyIGWResourceId
            /]
        [/#if]
    [/#if]

    [#if (resources["subnets"]!{})?has_content ]

        [#local subnetResources = resources["subnets"]]

        [#list subnetResources as tierId, zoneSubnets  ]

            [#local networkTier = getTier(tierId) ]
            [#local tierNetwork = getTierNetwork(tierId) ]

            [#local networkLink = tierNetwork.Link!{} ]
            [#local routeTableId = tierNetwork.RouteTable!"" ]
            [#local networkACLId = tierNetwork.NetworkACL!"" ]

            [#if !networkLink?has_content || !routeTableId?has_content || !networkACLId?has_content ]
                [@fatal
                    message="Tier Network configuration incomplete"
                    context=
                        tierNetwork +
                        {
                            "Link" : networkLink,
                            "RouteTable" : routeTableId,
                            "NetworkACL" : networkACLId
                        }
                /]

            [#else]

                [#local routeTable = getLinkTarget(occurrence, networkLink + { "RouteTable" : routeTableId }, false )]
                [#if ! routeTable?has_content ]
                    [@fatal
                        message="RouteTable not found for subnet"
                        detail="Make sure your subnet is configured with a RouteTable from your network component"
                        context={
                            "SubnetTier" : tierId,
                            "RouteTable" : routeTableId,
                            "Network" : networkLink
                        }
                    /]
                    [#continue]
                [/#if]

                [#local routeTableZones = routeTable.State.Resources["routeTables"] ]

                [#local networkACL = getLinkTarget(occurrence, networkLink + { "NetworkACL" : networkACLId }, false )]
                [#if ! networkACL?has_content ]
                    [@fatal
                        message="NetworkACL not found for subnet"
                        detail="Make sure your subnet is configured with a NetworkACL from your network component"
                        context={
                            "SubnetTier" : tierId,
                            "NetworkACL" : networkACLId,
                            "Network" : networkLink
                        }
                    /]
                    [#continue]
                [/#if]

                [#local networkACLId = networkACL.State.Resources["networkACL"].Id ]

                [#local tierSubnetIdRefs = []]

                [#list getZones() as zone]

                    [#if zoneSubnets[zone.Id]?has_content]

                        [#local zoneSubnetResources = zoneSubnets[zone.Id]]
                        [#local subnetId = zoneSubnetResources["subnet"].Id ]
                        [#local subnetName = zoneSubnetResources["subnet"].Name ]
                        [#local subnetAddress = zoneSubnetResources["subnet"].Address ]
                        [#local routeTableAssociationId = zoneSubnetResources["routeTableAssoc"].Id]
                        [#local networkACLAssociationId = zoneSubnetResources["networkACLAssoc"].Id]
                        [#local routeTableId = (routeTableZones[zone.Id]["routeTable"]).Id]

                        [#local tierSubnetIdRefs += [ getReference(subnetId) ]]

                        [#if deploymentSubsetRequired(NETWORK_COMPONENT_TYPE, true)]
                            [@createSubnet
                                id=subnetId
                                vpcId=vpcResourceId
                                zone=zone
                                cidr=subnetAddress
                                tags=getOccurrenceTags(
                                    occurrence,
                                    {
                                        "zone" : zone.Id,
                                        "network": (routeTable.Private!false)?then("private", "public")
                                    },
                                    [ networkTier, zone.Id]
                                )
                            /]
                            [@createRouteTableAssociation
                                id=routeTableAssociationId
                                subnetId=subnetId
                                routeTableId=routeTableId
                            /]
                            [@createNetworkACLAssociation
                                id=networkACLAssociationId
                                subnetId=subnetId
                                networkACLId=networkACLId
                            /]
                        [/#if]
                    [/#if]
                [/#list]

                [#local tierListId = formatId( AWS_VPC_SUBNETLIST_TYPE, core.Id, tierId) ]
                [#if deploymentSubsetRequired(NETWORK_COMPONENT_TYPE, true)]
                    [@cfOutput
                            tierListId,
                            {
                                "Fn::Join": [
                                    ",",
                                    tierSubnetIdRefs
                                ]
                            },
                            true
                    /]
                [/#if]

            [/#if]
        [/#list]
    [/#if]

    [#list (occurrence.Occurrences![])?filter(x -> x.Configuration.Solution.Enabled ) as subOccurrence]

        [@debug message="Suboccurrence" context=subOccurrence enabled=false /]

        [#local core = subOccurrence.Core ]
        [#local solution = subOccurrence.Configuration.Solution ]
        [#local resources = subOccurrence.State.Resources ]

        [#if ! solution.Enabled ]
            [#continue]
        [/#if]

        [#if core.Type == NETWORK_ROUTE_TABLE_COMPONENT_TYPE]

            [#local zoneRouteTables = resources["routeTables"] ]

            [#list getZones() as zone ]

                [#if zoneRouteTables[zone.Id]?has_content ]
                    [#local zoneRouteTableResources = zoneRouteTables[zone.Id] ]
                    [#local routeTableId = zoneRouteTableResources["routeTable"].Id]

                    [#if deploymentSubsetRequired(NETWORK_COMPONENT_TYPE, true)]
                        [@createRouteTable
                            id=routeTableId
                            vpcId=vpcResourceId
                            tags=getOccurrenceTags(occurrence, {"zone": zone.Id}, [zone.Id])
                        /]

                        [#if (zoneRouteTableResources["legacyIGWRoute"].Id!{})?has_content ]
                            [#local legacyIGWRouteId =  zoneRouteTableResources["legacyIGWRoute"].Id ]
                            [@createRoute
                                id=legacyIGWRouteId
                                routeTableId=routeTableId
                                destinationType="gateway"
                                destinationAttribute=getReference(legacyIGWResourceId)
                                destinationCidr="0.0.0.0/0"
                            /]
                        [/#if]

                    [/#if]
                [/#if]
            [/#list]
        [/#if]

        [#if core.Type == NETWORK_ACL_COMPONENT_TYPE ]

            [#local networkACLId = resources["networkACL"].Id]
            [#local networkACLRules = resources["rules"]]

            [#if deploymentSubsetRequired(NETWORK_COMPONENT_TYPE, true)]

                [#if resources["networkACL"].DefaultACL ]
                    [#local networkACLId = {
                        "Fn::GetAtt": [
                            vpcResourceId,
                            "DefaultNetworkAcl"
                        ]
                    }]
                [#else ]

                    [@createNetworkACL
                        id=networkACLId
                        vpcId=vpcResourceId
                        tags=getOccurrenceTags(occurrence)
                    /]
                [/#if]

                [#list networkACLRules as id, rule ]
                    [#local ruleId = rule.Id ]
                    [#local ruleConfig = solution.Rules[id] ]

                    [#if ! ((ports[ruleConfig.Destination.Port])!"")?has_content
                            || ! ((ports[ruleConfig.Source.Port])!"")?has_content ]
                        [@fatal
                            message="Invalid NetworkACL Ports"
                            context={
                                "Destination": {
                                    "Name": (ruleConfig.Destination.Port)!"",
                                    "Details": (ports[ruleConfig.Destination.Port])!{}
                                },
                                "Source": {
                                    "Name": (ruleConfig.Source.Port)!"",
                                    "Details": (ports[ruleConfig.Source.Port])!{}
                                }
                            }
                        /]
                    [/#if]

                    [#if (ruleConfig.Source.IPAddressGroups)?seq_contains("_localnet")
                            && (getUniqueArrayElements(ruleConfig.Source.IPAddressGroups))?size == 1 ]

                        [#local direction = "outbound" ]
                        [#local forwardIpAddresses = getGroupCIDRs(ruleConfig.Destination.IPAddressGroups, true, occurrence)]
                        [#local forwardPort = (ports[ruleConfig.Destination.Port])!{} ]
                        [#local returnIpAddresses = getGroupCIDRs(ruleConfig.Destination.IPAddressGroups, true, occurrence)]
                        [#local returnPort = (ports[ruleConfig.Source.Port])!{}]

                    [#elseif (ruleConfig.Destination.IPAddressGroups)?seq_contains("_localnet")
                                && (getUniqueArrayElements(ruleConfig.Source.IPAddressGroups))?size == 1 ]

                        [#local direction = "inbound" ]
                        [#local forwardIpAddresses = getGroupCIDRs(ruleConfig.Source.IPAddressGroups, true, occurrence)]
                        [#local forwardPort = (ports[ruleConfig.Destination.Port])!{}]
                        [#local returnIpAddresses = [ "0.0.0.0/0" ]]
                        [#local returnPort = (ports[ruleConfig.Source.Port])!{}]

                    [#else]
                        [@fatal
                            message="Invalid network ACL either source or destination must be configured as _localnet to define direction"
                            context=port
                        /]
                    [/#if]

                    [#if forwardPort?has_content ]
                        [#list forwardIpAddresses![] as ipAddress ]
                            [#local ruleOrder =  ruleConfig.Priority + ipAddress?index ]
                            [#local networkRule = {
                                    "RuleNumber" : ruleOrder,
                                    "Allow" : (ruleConfig.Action == "allow"),
                                    "CIDRBlock" : ipAddress
                                }]
                            [@createNetworkACLEntry
                                id=formatId(ruleId,direction,ruleOrder)
                                networkACLId=networkACLId
                                outbound=(direction=="outbound")
                                rule=networkRule
                                port=forwardPort
                            /]
                        [/#list]
                    [/#if ]

                    [#if returnPort?has_content ]
                        [#if ruleConfig.ReturnTraffic ]
                            [#local direction = (direction=="inbound")?then("outbound", "inbound")]

                            [#list returnIpAddresses![] as ipAddress ]
                                [#local ruleOrder = ruleConfig.Priority + ipAddress?index]

                                [#local networkRule = {
                                    "RuleNumber" : ruleOrder,
                                    "Allow" : (ruleConfig.Action == "allow"),
                                    "CIDRBlock" : ipAddress
                                    }]

                                [@createNetworkACLEntry
                                    id=formatId(ruleId,direction,ruleOrder)
                                    networkACLId=networkACLId
                                    outbound=(direction=="outbound")
                                    rule=networkRule
                                    port=returnPort
                                /]
                            [/#list]
                        [/#if]
                    [/#if]
                [/#list]
            [/#if]
        [/#if]
    [/#list]
[/#macro]
