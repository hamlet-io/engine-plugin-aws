[#ftl]
[#macro aws_lb_cf_deployment_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract subsets=["deploymentcontract", "prologue", "template", "cli", "epilogue" ] /]
[/#macro]

[#macro aws_lb_cf_deployment_deploymentcontract occurrence ]
    [@addDefaultAWSDeploymentContract prologue=true epilogue=true /]
[/#macro]

[#macro aws_lb_cf_deployment_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]

    [#local lbId = resources["lb"].Id ]
    [#local lbName = resources["lb"].Name ]
    [#local lbShortName = resources["lb"].ShortName ]

    [#local targetGroupSG = resources["targetGroupSG"] ]

    [#local lbLogs = solution.Logs ]
    [#local lbSecurityGroupIds = [targetGroupSG.Id] ]

    [#local wafAclResources = resources["wafacl"]!{} ]
    [#local wafSolution = solution.WAF]

    [#local wafLogStreamingResources = resources["wafLogStreaming"]!{} ]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "OpsData", "Encryption" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local operationsBucket = getExistingReference(baselineComponentIds["OpsData"]) ]
    [#local kmsKeyId = baselineComponentIds["Encryption"]]

    [#local networkProfile = getNetworkProfile(occurrence)]

    [#local occurrenceNetwork = getOccurrenceNetwork(occurrence) ]
    [#local networkLink = occurrenceNetwork.Link!{} ]

    [#local networkLinkTarget = getLinkTarget(occurrence, networkLink ) ]

    [#if ! networkLinkTarget?has_content ]
        [@fatal message="Network could not be found" context=networkLink /]
        [#return]
    [/#if]

    [#local networkConfiguration = networkLinkTarget.Configuration.Solution]
    [#local networkResources = networkLinkTarget.State.Resources ]

    [#local vpcId = networkResources["vpc"].Id ]

    [#local routeTableLinkTarget = getLinkTarget(occurrence, networkLink + { "RouteTable" : occurrenceNetwork.RouteTable })]
    [#local routeTableConfiguration = routeTableLinkTarget.Configuration.Solution ]
    [#local publicRouteTable = routeTableConfiguration.Public ]

    [#local engine = solution.Engine]
    [#local idleTimeout = solution.IdleTimeout]

    [#local securityProfile = getSecurityProfile(occurrence, core.Type, engine)]
    [#local loggingProfile = getLoggingProfile(occurrence)]

    [#local healthCheckPort = "" ]
    [#if engine == "classic" ]
        [#if solution.HealthCheckPort?has_content ]
            [#local healthCheckPort = ports[solution.HealthCheckPort]]
        [#else]
            [@precondition
                function="solution_lb"
                detail="No health check port provided"
            /]
        [/#if]
    [/#if]

    [#local portProtocols = [] ]
    [#local classicListeners = []]
    [#local ingressRules = [] ]
    [#local listenerPortsSeen = [] ]

    [#local classicPolicies = []]
    [#local classicStickinessPolicies = []]
    [#local classicConnectionDrainingTimeouts = []]

    [#local cleanupStates = {}]

    [#local lbListeners = []]
    [#local defaultActions = {}]

    [#local classicHTTPSPolicyName = "ELBSecurityPolicy"]
    [#if engine == "classic" ]
        [#local classicPolicies += [
            {
                "PolicyName" : classicHTTPSPolicyName,
                "PolicyType" : "SSLNegotiationPolicyType",
                "Attributes" : [{
                    "Name"  : "Reference-Security-Policy",
                    "Value" : securityProfile.HTTPSProfile
                }]
            }
        ]]
    [/#if]

    [#if deploymentSubsetRequired(LB_COMPONENT_TYPE, true) ]

        [@createSecurityGroup
            id=targetGroupSG.Id
            name=targetGroupSG.Name
            vpcId=vpcId
            description="Security group for LB to Target Group Access"
            tags=getOccurrenceTags(occurrence, {}, "TargetGroup")
        /]

        [@createSecurityGroupRulesFromNetworkProfile
            occurrence=occurrence
            groupId=targetGroupSG.Id
            networkProfile=networkProfile
            inboundPorts=[]
        /]
    [/#if]

    [#list solution.Links?values?filter(x -> x?is_hash && x.Enabled ) as link]
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

            [#if deploymentSubsetRequired(LB_COMPONENT_TYPE, true) ]
                [@createSecurityGroupRulesFromLink
                    occurrence=occurrence
                    groupId=targetGroupSG.Id
                    linkTarget=linkTarget
                    inboundPorts=[]
                    networkProfile=networkProfile
                /]
            [/#if]

            [#switch linkTargetCore.Type]
                [#case SERVICE_REGISTRY_SERVICE_COMPONENT_TYPE ]
                    [#local registryServiceId = linkTargetResources["service"].Id ]
                    [#local instanceAttributes = getCloudMapInstanceAttribute(
                                                    "alias",
                                                    getExistingReference(lbId, DNS_ATTRIBUTE_TYPE) )]

                    [#if deploymentSubsetRequired(LB_COMPONENT_TYPE, true) ]
                        [#local cloudMapInstanceId = formatDependentResourceId(
                                                            AWS_CLOUDMAP_INSTANCE_RESOURCE_TYPE, lbId, registryServiceId)]
                        [@createCloudMapInstance
                            id=cloudMapInstanceId
                            serviceId=registryServiceId
                            instanceId=core.ShortName
                            instanceAttributes=instanceAttributes
                        /]
                    [/#if]
                    [#break]
            [/#switch]
        [/#if]
    [/#list]

    [#list (occurrence.Occurrences![])?filter(x -> x.Configuration.Solution.Enabled && x.Core.Type == LB_BACKEND_COMPONENT_TYPE ) as subOccurrence]

        [#local core = subOccurrence.Core ]
        [#local solution = subOccurrence.Configuration.Solution ]
        [#local resources = subOccurrence.State.Resources ]

        [#local targetgroup = resources["targetgroup"]]
        [#local staticTargets = []]

        [#if engine != "application" ]
            [@fatal
                message="Backed Configuration only supported for application engine"
                context={
                    "Lb": occurrence.Core.RawId,
                    "Engine": engine,
                    "Backend": subOccurrence.Core.RawId
                }
            /]
            [#continue]
        [/#if]

        [#local port = (getReferenceData(PORT_REFERENCE_TYPE)[solution.Port])!{} ]
        [#if ! port?has_content ]
            [@fatal
                message="Unkown port for backend"
                context={
                    "LbId" : occurrence.Core.RawId,
                    "Backend" : subOccurrence.Core.RawId,
                    "Port" : solution.Port
                }
            /]
            [#continue]
        [/#if]

        [#if ["instance", "ip"]?seq_contains(solution.TargetType) &&
                ! ["HTTP", "HTTPS"]?seq_contains(port.Protocol) ]

            [@fatal
                message="Invalid destination port protocol - supports HTTP or HTTPS Protocols"
                context={
                    "lb": occurrence.Core.RawId,
                    "lbport": subOccurrence.Core.RawId,
                    "TargetType": solution.Forward.TargetType,
                    "Protocol": (port.Protocol)!""
                }
            /]
        [/#if]

        [#list (solution.StaticEndpoints.Links)?values?filter(
                    x -> x?is_hash && x.Enabled
                )?map(
                    x -> getLinkTarget(subOccurrence, x)
                )?filter(
                    x -> x?has_content
                ) as linkTarget ]

            [#local linkTargetCore = linkTarget.Core ]
            [#local linkTargetConfiguration = linkTarget.Configuration ]
            [#local linkTargetResources = linkTarget.State.Resources ]
            [#local linkTargetAttributes = linkTarget.State.Attributes ]

            [#if deploymentSubsetRequired(LB_COMPONENT_TYPE, true) ]
                [@createSecurityGroupRulesFromLink
                    occurrence=subOccurrence
                    groupId=targetGroupSG.Id
                    linkTarget=linkTarget
                    inboundPorts=[]
                    networkProfile=networkProfile
                /]
            [/#if]

            [#switch linkTargetCore.Type]
                [#case EXTERNALSERVICE_ENDPOINT_COMPONENT_TYPE]
                    [#local endpointPort = ports[linkTargetConfiguration.Solution.Port].Port ]

                    [#list asFlattenedArray(
                                getGroupCIDRs(linkTargetConfiguration.Solution.IPAddressGroups, true)
                            ?map(
                                x -> getHostsFromNetwork(x))) as endpointAddress ]
                        [#local staticTargets += getTargetGroupTarget(
                                    "ip",
                                    endpointAddress,
                                    endpointPort,
                                    solution.StaticEndpoints.External
                                )]
                    [/#list]
                    [#break]

                    [#case LAMBDA_FUNCTION_COMPONENT_TYPE]
                        [#local staticTargets += getTargetGroupTarget(
                            "lambda",
                            linkTargetAttributes["ARN"]
                        )]
                        [#break]
                    [#break]

                    [#case EC2_COMPONENT_TYPE]
                        [#list linkTargetResources["Zones"] as zone, resources ]
                            [#if solution.TargetType == "ip" ]
                                [#if getExistingReference(resources["ec2ENI"].Id, IP_ADDRESS_ATTRIBUTE_TYPE)?has_content ]
                                    [#local staticTargets +=
                                        getTargetGroupTarget(
                                            "ip",
                                            getExistingReference(resources["ec2ENI"].Id, IP_ADDRESS_ATTRIBUTE_TYPE),
                                            port.Port,
                                            false
                                        )]
                                [/#if]

                            [#elseif solution.TargetType == "instance" ]
                                [#if getExistingReference(resources["ec2Instance"].Id)?has_content ]
                                    [#local staticTargets +=
                                        getTargetGroupTarget(
                                            "instance",
                                            getExistingReference(resources["ec2Instance"].Id),
                                            port.Port,
                                            false
                                        )]
                                [/#if]
                            [/#if]
                        [/#list]
                        [#break]
            [/#switch]
        [/#list]

        [#local tgAttributes = (solution.StickinessTime > 0)?then(
                {
                    "stickiness.enabled" : true,
                    "stickiness.type" : "lb_cookie",
                    "stickiness.lb_cookie.duration_seconds" : solution.StickinessTime
                },
                {}
            ) +
            (solution.SlowStartTime > 0)?then(
                {
                    "slow_start.duration_seconds" : solution.SlowStartTime
                },
                {}
            ) +
            (solution.TargetType == "aws:lambda" && solution["aws:TargetType:lambda"].MultiValueHeaders )?then(
                {
                    "lambda.multi_value_headers.enabled": true
                },
                {}
            )]

        [@createTargetGroup
            id=targetgroup.Id
            destination=port
            attributes=tgAttributes
            targetType=solution.TargetType
            vpcId=vpcId
            targets=staticTargets
            tags=getOccurrenceTags(subOccurrence)
        /]
    [/#list]

    [#-- Port Mapping Rule Processing --]
    [#list (occurrence.Occurrences![])?filter(x -> x.Configuration.Solution.Enabled && x.Core.Type == LB_PORT_COMPONENT_TYPE ) as subOccurrence]

        [#local core = subOccurrence.Core ]
        [#local solution = subOccurrence.Configuration.Solution ]
        [#local resources = subOccurrence.State.Resources ]

        [#-- Determine if this is the first mapping for the source port --]
        [#-- The assumption is that all mappings for a given port share --]
        [#-- the same listenerId, so the same port number shouldn't be  --]
        [#-- defined with different names --]
        [#local listenerId = resources["listener"].Id ]

        [#local targetGroupId = (resources["targetgroup"].Id)!""]
        [#local targetGroupName = (resources["targetgroup"].Name)!"" ]
        [#local targetGroupRequired = true ]

        [#local listenerRuleId = resources["listenerRule"].Id ]
        [#local listenerRulePriority = resources["listenerRule"].Priority ]
        [#if listenerRulePriority?is_string && ["default", "_default"]?seq_contains(listenerRulePriority) ]
            [#local listenerRulePriority = "default" ]
        [/#if]

        [#local fqdn = resources["listenerRule"].FQDN ]

        [#local certificateId = ""]
        [#if ((resources["certificate"])!{})?has_content ]
            [#local certificateId = resources["certificate"].Id ]
        [/#if]

        [#local ruleCleanupScript = []]
        [#local cliCleanUpRequired = getExistingReference(listenerId, "cleanup")?has_content ]

        [#-- Determine the IP whitelisting required --]
        [#local portIpAddressGroups = solution.IPAddressGroups ]
        [#local cidrs = getGroupCIDRs(portIpAddressGroups, true, subOccurrence)]

        [#switch engine ]
            [#case "application"]
            [#case "classic"]
                [#local securityGroupRequired = true ]
                [#break]

            [#default]
                [#local securityGroupRequired = false ]
        [/#switch]

        [#if securityGroupRequired ]
            [#local securityGroupId = resources["sg"].Id]
            [#local securityGroupName = resources["sg"].Name]
            [#local securityGroupPorts = resources["sg"].Ports ]
        [/#if]

        [#-- Check source and destination ports --]
        [#local mapping = solution.Mapping!core.SubComponent.Name ]
        [#local source = (portMappings[mapping].Source)!"" ]
        [#local destination = (portMappings[mapping].Destination)!"" ]
        [#local sourcePort = (ports[source])!{} ]
        [#local destinationPort = (ports[destination])!{} ]

        [#if !(sourcePort?has_content && destinationPort?has_content)]
            [@fatal message="Invalid port mapping" context={"mapping": mapping, "source": source, "destination": destination} stop=true /]
        [/#if]

        [#local firstMappingForPort = !listenerPortsSeen?seq_contains(listenerId) ]
        [#switch engine ]
            [#case "application"]
                [#if solution.Path?is_sequence || solution.Path != "default" ]
                    [#-- Only create the listener for default mappings      --]
                    [#-- The ordering of ports changes with their naming    --]
                    [#-- so it isn't sufficient to use the first occurrence --]
                    [#-- of a listener                                      --]
                    [#local firstMappingForPort = false ]
                [/#if]
                [#break]
        [/#switch]
        [#if firstMappingForPort]
            [#local listenerPortsSeen += [listenerId] ]

            [#local lbListeners += [
                {
                    "Id" : listenerId,
                    "Source" : source,
                    "SourcePort" : sourcePort,
                    "DefaultTargetGroupId" : targetGroupId,
                    "CertificateId" : (certificateId)!""
                }
            ]]
        [/#if]

        [#if !(sourcePort?has_content && destinationPort?has_content)]
            [#continue ]
        [/#if]
        [#local portProtocols += [ sourcePort.Protocol ] ]
        [#local portProtocols += [ destinationPort.Protocol] ]

        [#-- Port Protocol Validation --]
        [#switch engine ]
            [#case "network" ]

                [#if ! ["UDP", "TCP", "SSL"]?seq_contains(sourcePort.Protocol)]
                    [@fatal
                        message="Invalid source port protocol - supports TCP or UDP or SSL Protocols"
                        context={
                            "lb": occurrence.Core.RawId,
                            "lbport": subOccurrence.Core.RawId,
                            "TargetType": solution.Forward.TargetType,
                            "Protocol": sourcePort.Protocol
                        }
                    /]
                [/#if]

                [#if ["instance", "ip"]?seq_contains(solution.Forward.TargetType) &&
                        ! ["HTTP", "HTTPS", "TCP"]?seq_contains(destinationPort.Protocol) &&
                        ! isPresent(solution.Backend) ]

                    [@fatal
                        message="Invalid destination port protocol - supports HTTP,HTTPS or TCP Protocols"
                        context={
                            "lb": occurrence.Core.RawId,
                            "lbport": subOccurrence.Core.RawId,
                            "TargetType": solution.Forward.TargetType,
                            "Protocol": destinationPort.Protocol
                        }
                    /]
                [/#if]

                [#break]

            [#case "application" ]

                [#if ! ["HTTP", "HTTPS"]?seq_contains(sourcePort.Protocol)]
                    [@fatal
                        message="Invalid source port protocol - supports HTTP or HTTPS Protocols"
                        context={
                            "lb": occurrence.Core.RawId,
                            "lbport": subOccurrence.Core.RawId,
                            "TargetType": solution.Forward.TargetType,
                            "Protocol": sourcePort.Protocol
                        }
                    /]
                [/#if]

                [#if ["instance", "ip"]?seq_contains(solution.Forward.TargetType) &&
                        ! ["HTTP", "HTTPS"]?seq_contains(destinationPort.Protocol) &&
                        ! isPresent(solution.Backend) ]

                    [@fatal
                        message="Invalid destination port protocol - supports HTTP or HTTPS Protocols"
                        context={
                            "lb": occurrence.Core.RawId,
                            "lbport": subOccurrence.Core.RawId,
                            "TargetType": solution.Forward.TargetType,
                            "Protocol": destinationPort.Protocol
                        }
                    /]
                [/#if]

                [#if ["aws:alb"]?seq_contains(solution.Forward.TargetType) &&
                        ! ["TCP"]?seq_contains(destinationPort.Protocol) &&
                        ! isPresent(solution.Backend)]

                    [@fatal
                        message="Invalid destination port protocol - supports HTTP or HTTPS Protocols"
                        context={
                            "lb": occurrence.Core.RawId,
                            "lbport": subOccurrence.Core.RawId,
                            "TargetType": solution.Forward.TargetType,
                            "Protocol": destinationPort.Protocol
                        }
                    /]
                [/#if]

                [#break]
        [/#switch]

        [#-- forwarding attributes --]
        [#local tgAttributes = {}]
        [#local classicConnectionDrainingTimeouts += [ solution.Forward.DeregistrationTimeout ]]

        [#local listenerForwardRule = true]

        [#local listenerRuleActions = [] ]

        [#local staticTargets = []]

        [#-- Path processing --]
        [#switch engine ]
            [#case "application"]
                [#if solution.Path?is_string]

                    [#if solution.Path == "default" ]
                        [#local path = "*"]
                    [#else]
                        [#if solution.Path?ends_with("/") && solution.Path != "/" ]
                            [#local path = solution.Path?ensure_ends_with("*")]
                        [#else]
                            [#local path = solution.Path ]
                        [/#if]
                    [/#if]

                [#elseif solution.Path?is_sequence]
                    [#local path = solution.Path]
                [/#if]

                [#if listenerRulePriority?is_string && listenerRulePriority == "default" ]

                    [#if solution.HostFilter || (! solution.Path?is_string &&  solution.Path != "default") ]
                        [@fatal
                            message="Request conditions can not be used for default rules"
                            context={
                                "Lb" : lbId,
                                "PortMapping" : core.RawId,
                                "Conditions" : {
                                    "HostFilter" : solution.HostFilter,
                                    "Path" : solution.Path
                                }
                            }
                        /]
                    [/#if]
                [/#if]
                [#break]

            [#default]
                [#if (solution.Conditions)?has_content ]
                    [@fatal
                        message="Conditions not supported for this engine type"
                        context={
                            "Engine" : engine,
                            "Conditions" : solution.Conditions
                        }
                    /]
                [/#if]
                [#local path = "" ]
                [#break]
        [/#switch]
        [#local listenerRuleConditions = getListenerRuleCondition("path-pattern", path) ]

        [#if engine == "application" ]
            [#-- FQDN processing --]
            [#if solution.HostFilter ]
                [#list resources["domainRedirectRules"]!{} as key, rule]

                    [#if deploymentSubsetRequired(LB_COMPONENT_TYPE, true) ]
                        [@createListenerRule
                            id=rule.Id
                            listenerId=listenerId
                            actions=getListenerRuleRedirectAction(
                                    "#\{protocol}",
                                    "#\{port}",
                                    fqdn,
                                    "#\{path}",
                                    "#\{query}")
                            conditions=getListenerRuleCondition("host-header", rule.RedirectFrom)
                            priority=rule.Priority
                        /]
                    [/#if]

                [/#list]

                [#local listenerRuleConditions += getListenerRuleCondition("host-header", fqdn) ]
                [#if ! fqdn?has_content]
                    [@fatal message="HostName/Certificate property is required when HostFilter:true " context=solution /]
                [/#if]
            [/#if]

            [#list solution.Conditions as id, condition ]
                [#if condition.Enabled ]
                    [#switch condition.Type ]
                        [#case "httpHeader" ]
                            [#local listenerRuleConditions +=
                                getListenerRuleCondition(
                                    "http-header",
                                    {
                                        "HeaderName" : (condition["type:httpHeader"].HeaderName)!"HamletFatal: Missing HeaderName for httpHeader filter",
                                        "Values" : (condition["type:httpHeader"].HeaderValues)!"HamletFatal: Missing HeaderValues for httpHeader filter"
                                    }
                                )]
                            [#break]
                        [#case "httpRequestMethod" ]
                            [#local listenerRuleConditions +=
                                getListenerRuleCondition(
                                    "http-request-method",
                                    (condition["type:httpRequestMethod"].Methods)!"HamletFatal: Missing Methods for httpRequestMethod condition"
                                )]
                            [#break]
                        [#case "httpQueryString" ]
                            [#list condition["type:httpQueryString"] as id,query ]
                                [#local listenerRuleConditions +=
                                    getListenerRuleCondition(
                                        "query-string",
                                        {
                                            "Key" : (query.Key)!"HamletFatal: Missing Key in httpQueryString condition",
                                            "Value" : (query.Value)!"HamletFatal: Missing Value in httpQueryString condition"
                                        }
                                    )]
                            [/#list]
                            [#break]
                        [#case "SourceIP" ]
                            [#local listenerRuleConditions +=
                                getListenerRuleCondition(
                                    "source-ip",
                                    getGroupCIDRs(condition["type:SourceIP"].IPAddressGroups, true, subOccurrence)
                                )]
                            [#break]
                    [/#switch]
                [/#if]
            [/#list]

            [#-- Redirect rule processing --]
            [#if isPresent(solution.Redirect) ]
                [#local targetGroupRequired = false ]
                [#local listenerForwardRule = false ]

                [#if deploymentSubsetRequired(LB_COMPONENT_TYPE, true) ]

                    [#local redirectAction = getListenerRuleRedirectAction(
                                        solution.Redirect.Protocol,
                                        solution.Redirect.Port,
                                        solution.Redirect.Host,
                                        solution.Redirect.Path,
                                        solution.Redirect.Query,
                                        solution.Redirect.Permanent)]

                    [#if listenerRulePriority?is_string &&
                            listenerRulePriority == "default" ]

                        [#if ! ((defaultActions[lbListener.Source])!{})?has_content ]
                            [#local defaultActions += {
                                source : redirectAction
                            }]

                        [#else]
                            [@fatal
                                message="Default action for source {source} port already in use"
                                context={
                                    "Source" : source,
                                    "CurrentRule" : defaultActions[source],
                                    "NewRule" : solution
                                }
                            /]
                        [/#if]
                    [#else]
                        [@createListenerRule
                            id=listenerRuleId
                            listenerId=listenerId
                            actions=redirectAction
                            conditions=listenerRuleConditions
                            priority=listenerRulePriority
                        /]
                    [/#if]
                [/#if]
            [/#if]

            [#-- Fixed rule processing --]
            [#if isPresent(solution.Fixed) ]
                [#local targetGroupRequired = false ]
                [#local listenerForwardRule = false ]
                [#local fixedMessage = getOccurrenceSettingValue(subOccurrence, ["Fixed", "Message"], true) ]
                [#local fixedContentType = getOccurrenceSettingValue(subOccurrence, ["Fixed", "ContentType"], true) ]
                [#local fixedStatusCode = getOccurrenceSettingValue(subOccurrence, ["Fixed", "StatusCode"], true) ]
                [#if deploymentSubsetRequired(LB_COMPONENT_TYPE, true) ]

                    [#local fixedRule = getListenerRuleFixedAction(
                                            contentIfContent(
                                                fixedMessage,
                                                solution.Fixed.Message),
                                            contentIfContent(
                                                fixedContentType,
                                                solution.Fixed.ContentType),
                                            contentIfContent(
                                                fixedStatusCode,
                                                solution.Fixed.StatusCode))]

                    [#if listenerRulePriority?is_string &&
                        listenerRulePriority == "default" ]
                        [#if ! ((defaultActions[lbListener.Source])!{})?has_content ]
                            [#local defaultActions += {
                                source : fixedRule
                            }]

                        [#else]
                            [@fatal
                                message="Default action for source {source} port already in use"
                                context={
                                    "Source" : source,
                                    "CurrentRule" : defaultActions[source],
                                    "NewRule" : solution
                                }
                            /]
                        [/#if]
                    [#else]
                        [@createListenerRule
                            id=listenerRuleId
                            listenerId=listenerId
                            actions=fixedRule
                            conditions=listenerRuleConditions
                            priority=listenerRulePriority
                        /]
                    [/#if]
                [/#if]
            [/#if]

            [#-- Backend rule management --]
            [#if isPresent(solution.Backend) ]
                [#local targetGroupRequired = false ]

                [#local backendLink = getLinkTarget(subOccurrence, solution.Backend.Link, false)]

                [#if ! backendLink?has_content]
                    [#continue]
                [/#if]

                [#if (getOccurrenceDeploymentUnit(backendLink) != getOccurrenceDeploymentUnit(subOccurrence) ) && ! isLinkTargetActive(backendLink) ]
                    [@fatal
                        message="Backend link outside of deployment must be active"
                        context={
                            "Lb": occurrence.Core.RawId,
                            "PortMapping": subOccurrence.Core.RawId,
                            "Backend" : solution.Backend.Link
                        }
                    /]
                    [#continue]
                [/#if]

                [#if backendLink.Core.Type != LB_BACKEND_COMPONENT_TYPE ]
                    [@fatal
                        message="Invalid component for backend"
                        context={
                            "Lb": occurrence.Core.RawId,
                            "PortMapping": subOccurrence.Core.RawId,
                            "Backend" : solution.Backend.Link,
                            "Type" : backendLinkCore.Type
                        }
                    /]
                    [#continue]
                [/#if]

                [#local targetGroupId = backendLink.State.Resources.targetgroup.Id ]
            [/#if]
        [/#if]

        [#-- Use presence of links to determine rule required --]
        [#-- More than one link is an error --]
        [#local linkCount = 0 ]
        [#list solution.Links?values as link]
            [#if link?is_hash]
                [#local linkCount += 1 ]
                [#if linkCount > 1 ]
                    [@fatal
                        message="A port mapping can only have a maximum of one link"
                        context=subOccurrence
                    /]
                    [#continue]
                [/#if]

                [#local linkTarget = getLinkTarget(occurrence, link) ]

                [@debug message="Link Target" context=linkTarget enabled=false /]

                [#if !linkTarget?has_content]
                    [#continue]
                [/#if]

                [#local linkTargetCore = linkTarget.Core ]
                [#local linkTargetConfiguration = linkTarget.Configuration ]
                [#local linkTargetResources = linkTarget.State.Resources ]
                [#local linkTargetAttributes = linkTarget.State.Attributes ]

                [#if deploymentSubsetRequired(LB_COMPONENT_TYPE, true)
                        && securityGroupRequired ]
                    [@createSecurityGroupRulesFromLink
                        occurrence=subOccurrence
                        groupId=securityGroupId
                        linkTarget=linkTarget
                        inboundPorts=[ securityGroupPorts ]
                        networkProfile=networkProfile
                    /]
                [/#if]

                [#switch linkTargetCore.Type]

                    [#case USERPOOL_COMPONENT_TYPE]
                    [#case USERPOOL_CLIENT_COMPONENT_TYPE]
                    [#case "external" ]
                        [#local cognitoIntegration = true ]
                        [#local listenerForwardRule = false ]

                        [#local userPoolSessionCookieName = solution.Authentication.SessionCookieName ]
                        [#local userPoolSessionTimeout = solution.Authentication.SessionTimeout ]

                        [#local userPoolDomain = linkTargetAttributes["UI_FQDN"]!"HamletFatal: Userpool FQDN not found" ]
                        [#local userPoolArn = linkTargetAttributes["USER_POOL_ARN"]!"HamletFatal: Userpool ARN not found" ]
                        [#local userPoolClientId = linkTargetAttributes["CLIENT"]!"HamletFatal: Userpool client id not found"  ]
                        [#local userPoolOauthScope = linkTargetAttributes["LB_OAUTH_SCOPE"]!"HamletFatal: Userpool OAuth scope not found"  ]

                        [#if deploymentSubsetRequired(LB_COMPONENT_TYPE, true) && engine == "application" ]

                            [#local authForwardRule =
                                    getListenerRuleAuthCognitoAction(
                                            userPoolArn,
                                            userPoolClientId,
                                            userPoolDomain,
                                            userPoolSessionCookieName,
                                            userPoolSessionTimeout,
                                            userPoolOauthScope,
                                            1
                                    ) +
                                    getListenerRuleForwardAction(targetGroupId, 2)]

                            [#if listenerRulePriority?is_string &&
                                listenerRulePriority == "default" ]
                                [#if ! ((defaultActions[lbListener.Source])!{})?has_content ]
                                    [#local defaultActions += {
                                        source : authForwardRule
                                    }]

                                [#else]
                                    [@fatal
                                        message="Default action for source {source} port already in use"
                                        context={
                                            "Source" : source,
                                            "CurrentRule" : defaultActions[source],
                                            "NewRule" : solution
                                        }
                                    /]
                                [/#if]
                            [#else]

                                [@createListenerRule
                                    id=listenerRuleId
                                    listenerId=listenerId
                                    actions=authForwardRule
                                    conditions=listenerRuleConditions
                                    priority=listenerRulePriority
                                /]
                            [/#if]
                        [/#if]
                        [#break]

                    [#case SPA_COMPONENT_TYPE]
                        [#local targetGroupRequired = false ]
                        [#local listenerForwardRule = false ]
                        [#if deploymentSubsetRequired(LB_COMPONENT_TYPE, true) && engine == "application"  ]

                            [#local spaRedirectRule =
                                        getListenerRuleRedirectAction(
                                            "HTTPS",
                                            "443",
                                            linkTargetAttributes.FQDN,
                                            "",
                                            "",
                                            false
                                        )]

                            [#if listenerRulePriority?is_string &&
                                listenerRulePriority == "default" ]
                                [#if ! ((defaultActions[lbListener.Source])!{})?has_content ]
                                    [#local defaultActions += {
                                        source : spaRedirectRule
                                    }]

                                [#else]
                                    [@fatal
                                        message="Default action for source {source} port already in use"
                                        context={
                                            "Source" : source,
                                            "CurrentRule" : defaultActions[source],
                                            "NewRule" : solution
                                        }
                                    /]
                                [/#if]
                            [#else]
                                [@createListenerRule
                                    id=listenerRuleId
                                    listenerId=listenerId
                                    actions=spaRedirectRule
                                    conditions=listenerRuleConditions
                                    priority=listenerRulePriority
                                /]
                            [/#if]
                        [/#if]
                        [#break]
                [/#switch]
            [/#if]
        [/#list]

        [#-- Create the security group for the listener --]
        [#if deploymentSubsetRequired(LB_COMPONENT_TYPE, true) &&
                securityGroupRequired ]

            [#local lbSecurityGroupIds = combineEntities( lbSecurityGroupIds, [securityGroupId], UNIQUE_COMBINE_BEHAVIOUR) ]

            [@createSecurityGroup
                id=securityGroupId
                name=securityGroupName
                vpcId=vpcId
                tags=getOccurrenceTags(subOccurrence)
            /]

            [@createSecurityGroupRulesFromNetworkProfile
                occurrence=subOccurrence
                groupId=securityGroupId
                networkProfile=networkProfile
                inboundPorts=securityGroupPorts
            /]

            [#local ingressNetworkRule = {
                    "Ports" : [ securityGroupPorts ],
                    "IPAddressGroups" : portIpAddressGroups
            }]

            [@createSecurityGroupIngressFromNetworkRule
                occurrence=subOccurrence
                groupId=securityGroupId
                networkRule=ingressNetworkRule
            /]

        [/#if]

        [#list solution.Forward.StaticEndpoints.Links as id,link ]
            [#if link?is_hash]
                [#local linkTarget = getLinkTarget(subOccurrence, link) ]

                [@debug message="Link Target" context=linkTarget enabled=false /]

                [#if !linkTarget?has_content]
                    [#continue]
                [/#if]

                [#local linkTargetCore = linkTarget.Core ]
                [#local linkTargetConfiguration = linkTarget.Configuration ]
                [#local linkTargetResources = linkTarget.State.Resources ]
                [#local linkTargetAttributes = linkTarget.State.Attributes ]

                [#if deploymentSubsetRequired(LB_COMPONENT_TYPE, true)
                        && securityGroupRequired ]
                    [@createSecurityGroupRulesFromLink
                        occurrence=subOccurrence
                        groupId=securityGroupId
                        linkTarget=linkTarget
                        inboundPorts=[ securityGroupPorts ]
                        networkProfile=networkProfile
                    /]
                [/#if]

                [#switch linkTargetCore.Type]
                    [#case EXTERNALSERVICE_ENDPOINT_COMPONENT_TYPE]
                        [#local endpointPort = ports[linkTargetConfiguration.Solution.Port].Port ]

                        [#list asFlattenedArray(
                                    getGroupCIDRs(linkTargetConfiguration.Solution.IPAddressGroups, true)
                                ?map(
                                    x -> getHostsFromNetwork(x))) as endpointAddress ]
                            [#local staticTargets += getTargetGroupTarget("ip", endpointAddress, endpointPort, solution.Forward.StaticEndpoints.External)]
                        [/#list]
                        [#break]

                    [#case LB_PORT_COMPONENT_TYPE]
                        [#if engine != "network" || linkTarget.State.Attributes.ENGINE != "application" ]
                            [@fatal
                                message="Only network load balancers can use application load balancers as targets"
                                context={
                                    "LB" : occurrence.Core.RawId,
                                    "Port" : subOccurrence.Core.RawId,
                                    "Link" : linkTarget.Core.RawId
                                }
                            /]
                        [/#if]

                        [#local staticTargets += getTargetGroupTarget(
                                "alb",
                                getArn(linkTarget.State.Attributes.LB),
                                linkTarget.State.Attributes.SOURCE_PORT
                            )]
                        [#break]

                    [#case LAMBDA_FUNCTION_COMPONENT_TYPE]
                        [#local staticTargets += getTargetGroupTarget(
                            "lambda",
                            linkTargetAttributes["ARN"]
                        )]
                        [#break]

                    [#case EC2_COMPONENT_TYPE]
                        [#list linkTargetResources["Zones"] as zone, resources ]
                            [#if solution.Forward.TargetType == "ip" ]
                                [#if getExistingReference(resources["ec2ENI"].Id, IP_ADDRESS_ATTRIBUTE_TYPE)?has_content ]
                                    [#local staticTargets +=
                                        getTargetGroupTarget(
                                            "ip",
                                            getExistingReference(resources["ec2ENI"].Id, IP_ADDRESS_ATTRIBUTE_TYPE),
                                            destinationPort.Port,
                                            false
                                        )]
                                [/#if]
                            [#elseif solution.Forward.TargetType == "instance" ]
                                [#if getExistingReference(resources["ec2Instance"].Id)?has_content ]
                                    [#local staticTargets +=
                                        getTargetGroupTarget(
                                            "instance",
                                            getExistingReference(resources["ec2Instance"].Id),
                                            destinationPort.Port,
                                            false
                                        )]
                                [/#if]
                            [/#if]
                        [/#list]
                        [#break]
                [/#switch]
            [/#if]
        [/#list]

        [#-- Process the mapping --]
        [#switch engine ]
            [#case "application"]
                [#local tgAttributes +=
                    (solution.Forward.StickinessTime > 0)?then(
                        {
                            "stickiness.enabled" : true,
                            "stickiness.type" : "lb_cookie",
                            "stickiness.lb_cookie.duration_seconds" : solution.Forward.StickinessTime
                        },
                        {}
                    ) +
                    (solution.Forward.SlowStartTime > 0)?then(
                        {
                            "slow_start.duration_seconds" : solution.Forward.SlowStartTime
                        },
                        {}
                    ) +
                    (solution.Forward.TargetType == "aws:lambda" && solution.Forward["aws:TargetType:lambda"].MultiValueHeaders )?then(
                        {
                            "lambda.multi_value_headers.enabled": true
                        },
                        {}
                    )
                ]

                [#-- This is to handle the migration from creating listener rules via the cli into Cloudformation --]
                [#if firstMappingForPort ]
                    [#if getExistingReference(listenerId)?has_content && ! getExistingReference(listenerRuleId)?has_content ]
                        [#local ruleCleanupScript += [
                                "cleanup_elbv2_rules" +
                                "       \"" + getRegion() + "\" " +
                                "       \"" + getExistingReference(listenerId, ARN_ATTRIBUTE_TYPE) + "\" "
                            ]]
                    [/#if]

                    [#if deploymentSubsetRequired("prologue", false)
                        && !cliCleanUpRequired
                        && listenerId?has_content
                        && ruleCleanupScript?has_content ]

                        [#local cleanupContent = [
                                r'case ${STACK_OPERATION} in',
                                r'  create|update)',
                                r'    # Apply CLI level updates to ELB listener',
                                '    info "Removing rules created by cli rules - listener ${listenerId}"'
                            ] +
                            ruleCleanupScript +
                            [
                                r'    ;;',
                                r'esac'
                            ]]

                        [@addToDefaultBashScriptOutput
                            content=cleanupContent
                        /]
                    [/#if]
                [/#if]

                [#local cleanupStates += { formatId(listenerId, "cleanup")  : true?c }]

                [#-- Basic Forwarding --]
                [#if listenerForwardRule ]
                    [#if deploymentSubsetRequired(LB_COMPONENT_TYPE, true) ]

                        [#local forwardRule = getListenerRuleForwardAction(targetGroupId)]

                        [#if listenerRulePriority?is_string &&
                            listenerRulePriority == "default" ]
                            [#if ! ((defaultActions[lbListener.Source])!{})?has_content ]
                                [#local defaultActions += {
                                    source : forwardRule
                                }]

                            [#else]
                                [@fatal
                                    message="Default action for source {source} port already in use"
                                    context={
                                        "Source" : source,
                                        "CurrentRule" : defaultActions[source],
                                        "NewRule" : solution
                                    }
                                /]
                            [/#if]
                        [#else]

                            [@createListenerRule
                                id=listenerRuleId
                                listenerId=listenerId
                                actions=forwardRule
                                conditions=listenerRuleConditions
                                priority=listenerRulePriority
                            /]
                        [/#if]
                    [/#if]
                [/#if]

            [#case "network"]

                [#if ! ["aws:alb", "aws:lambda"]?seq_contains(solution.Forward.TargetType)]
                    [#local tgAttributes +=
                        {
                            "deregistration_delay.timeout_seconds" : solution.Forward.DeregistrationTimeout
                        }]
                [/#if]
                [#switch solution.Forward.ClientIP!""]
                    [#case "preserve"]
                        [#local tgAttributes += { "preserve_client_ip.enabled" : true } ]
                        [#break]

                    [#case "proxy_protocol"]
                        [#local tgAttributes += { "proxy_protocol_v2.enabled" : true } ]
                        [#break]
                [/#switch]

                [#if engine == "network" && deploymentSubsetRequired(LB_COMPONENT_TYPE, true) ]
                    [@createTargetGroup
                        id=targetGroupId
                        destination=destinationPort
                        attributes=tgAttributes
                        targetType=solution.Forward.TargetType
                        vpcId=vpcId
                        targets=staticTargets
                        tags=getOccurrenceTags(subOccurrence)
                    /]
                [/#if]

                [#if ( targetGroupRequired ) &&
                    ( engine == "application" ) &&
                    deploymentSubsetRequired(LB_COMPONENT_TYPE, true) ]

                    [@createTargetGroup
                        id=targetGroupId
                        destination=destinationPort
                        attributes=tgAttributes
                        targetType=solution.Forward.TargetType
                        vpcId=vpcId
                        targets=staticTargets
                        tags=getOccurrenceTags(subOccurrence)
                    /]
                [/#if]

                [#break]

            [#case "classic"]
                [#if firstMappingForPort ]
                    [#local classicListenerPolicyNames = []]
                    [#local classicSSLRequired = sourcePort.Certificate!false ]

                    [#if classicSSLRequired ]
                        [#local classicListenerPolicyNames += [
                            classicHTTPSPolicyName
                        ]]
                    [/#if]

                    [#if solution.Forward.StickinessTime > 0 ]
                        [#local stickinessPolicyName = formatName(core.Name, "sticky") ]
                        [#local classicListenerPolicyNames += [ stickinessPolicyName ]]
                        [#local classicStickinessPolicies += [
                            {
                                "PolicyName" : stickinessPolicyName,
                                "CookieExpirationPeriod" : solution.Forward.StickinessTime
                            }
                        ]]
                    [/#if]

                    [#local classicListeners +=
                        [
                            {
                                "LoadBalancerPort" : sourcePort.Port,
                                "Protocol" : sourcePort.Protocol,
                                "InstancePort" : destinationPort.Port,
                                "InstanceProtocol" : destinationPort.Protocol
                            }  +
                            attributeIfTrue(
                                "SSLCertificateId",
                                classicSSLRequired,
                                getReference(certificateId, ARN_ATTRIBUTE_TYPE, getRegion())
                            ) +
                            attributeIfContent(
                                "PolicyNames",
                                classicListenerPolicyNames
                            )
                        ]
                    ]
                [/#if]
                [#break]
        [/#switch]
    [/#list]

    [#-- Manage alerts for occurrences --]
    [#list asFlattenedArray( [ occurrence, occurrence.Occurrences![] ], true )?filter(x -> x.Configuration.Solution.Enabled) as subOccurrence]
        [#local core = subOccurrence.Core]
        [#local solution = subOccurrence.Configuration.Solution]
        [#local resources = subOccurrence.State.Resources]

        [#if deploymentSubsetRequired(LB_COMPONENT_TYPE, true) ]
            [#list (solution.Alerts?values)?filter(x -> x.Enabled) as alert ]

                [#local monitoredResources = getCWMonitoredResources(core.Id, resources, alert.Resource)]
                [#list monitoredResources as name,monitoredResource ]

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
        [/#if]
    [/#list]

    [#-- Reset common variables to this scope (from subOccurrence scope above) --]
    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]

    [#if cleanupStates?has_content ]
        [#if deploymentSubsetRequired("prologue", false)]
            [@addToDefaultBashScriptOutput
                content=
                    pseudoStackOutputScript(
                        "CLI Rule Cleanup",
                        cleanupStates
                    )
            /]
        [/#if]
    [/#if]

    [#if (occurrence.Occurrences![])?filter(x -> x.Core.Type == LB_PORT_COMPONENT_TYPE )?has_content ]
        [#switch engine ]
            [#case "application"]
                [#if wafLogStreamingResources?has_content ]

                    [@setupLoggingFirehoseStream
                        occurrence=occurrence
                        componentSubset=LB_COMPONENT_TYPE
                        resourceDetails=wafLogStreamingResources
                        destinationLink=baselineLinks["OpsData"]
                        bucketPrefix="WAF"
                        cloudwatchEnabled=true
                        cmkKeyId=kmsKeyId
                        loggingProfile=loggingProfile
                    /]

                    [@enableWAFLogging
                        wafaclId=wafAclResources.acl.Id
                        wafaclArn=wafAclResources.acl.Arn
                        componentSubset=LB_COMPONENT_TYPE
                        deliveryStreamId=wafLogStreamingResources["stream"].Id
                        deliveryStreamArns=[ wafLogStreamingResources["stream"].Arn ]
                        regional=true
                    /]
                [/#if]
                [#if wafAclResources?has_content ]
                    [#if deploymentSubsetRequired(LB_COMPONENT_TYPE, true) ]
                        [#-- Create a WAF ACL if required --]
                        [@createWAFAclFromSecurityProfile
                            id=wafAclResources.acl.Id
                            name=wafAclResources.acl.Name
                            metric=wafAclResources.acl.Name
                            wafSolution=wafSolution
                            securityProfile=securityProfile
                            occurrence=occurrence
                            regional=true
                        /]
                        [@createWAFAclAssociation
                            id=wafAclResources.association.Id
                            wafaclId=wafAclResources.acl.Arn
                            endpointId=getReference(lbId)
                        /]
                    [/#if]
                [/#if]

            [#case "network"]
                [#if deploymentSubsetRequired(LB_COMPONENT_TYPE, true) ]
                    [@createALB
                        id=lbId
                        name=lbName
                        shortName=lbShortName
                        tier=core.Tier
                        component=core.Component
                        securityGroups=lbSecurityGroupIds
                        networkResources=networkResources
                        publicEndpoint=publicRouteTable
                        logs=lbLogs
                        type=engine
                        bucket=operationsBucket
                        idleTimeout=idleTimeout
                        tags=getOccurrenceTags(occurrence)
                        dropInvalidHeaders=solution["aws:engine:application"].DropInvalidHeaders
                        deletionProtection=solution["deployment:Locks"].Delete
                    /]

                    [#if resources["apiGatewayLink"]?has_content ]
                        [@createAPIGatewayVPCLink
                            id=resources["apiGatewayLink"].Id
                            name=resources["apiGatewayLink"].Name
                            networkLBId=lbId
                        /]
                    [/#if]

                    [#list lbListeners as lbListener ]
                        [#if deploymentSubsetRequired(LB_COMPONENT_TYPE, true) ]

                            [#switch engine]
                                [#case "network"]
                                    [#if ! ((defaultActions[lbListener.Source])!{})?has_content ]
                                        [#local defaultActions += { lbListener.Source : getListenerRuleForwardAction(lbListener.DefaultTargetGroupId)} ]
                                    [/#if]
                                    [#break]

                                [#case "application"]
                                    [#if ! ((defaultActions[lbListener.Source])!{})?has_content ]
                                        [#local defaultActions += {
                                            lbListener.Source : getListenerRuleFixedAction(
                                                "Access Denied - Last Rule",
                                                "text/plain",
                                                403
                                            )
                                        }]
                                    [/#if]
                                    [#break]
                            [/#switch]

                            [@createALBListener
                                id=lbListener.Id
                                port=lbListener.SourcePort
                                albId=lbId
                                defaultActions=defaultActions[lbListener.Source]
                                certificateId=lbListener.CertificateId
                                sslPolicy=securityProfile.HTTPSProfile
                            /]
                        [/#if]
                    [/#list]
                [/#if]
                [#break]

            [#case "classic"]

                [#local healthCheck = {
                    "Target" : getHealthCheckProtocol(healthCheckPort)?upper_case + ":"
                                + (healthCheckPort.HealthCheck.Port!healthCheckPort.Port)?c + healthCheckPort.HealthCheck.Path!"",
                    "HealthyThreshold" : healthCheckPort.HealthCheck.HealthyThreshold,
                    "UnhealthyThreshold" : healthCheckPort.HealthCheck.UnhealthyThreshold,
                    "Interval" : healthCheckPort.HealthCheck.Interval,
                    "Timeout" : healthCheckPort.HealthCheck.Timeout
                }]

                [#if deploymentSubsetRequired(LB_COMPONENT_TYPE, true) ]
                    [@createClassicLB
                        id=lbId
                        name=lbName
                        shortName=lbShortName
                        tier=core.Tier
                        component=core.Component
                        listeners=classicListeners
                        healthCheck=healthCheck
                        securityGroups=lbSecurityGroupIds
                        networkResources=networkResources
                        publicEndpoint=publicRouteTable
                        logs=lbLogs
                        multiAZ=solution.MultiAZ
                        bucket=operationsBucket
                        idleTimeout=idleTimeout
                        deregistrationTimeout=(classicConnectionDrainingTimeouts?reverse)[0]
                        stickinessPolicies=classicStickinessPolicies
                        policies=classicPolicies
                        tags=getOccurrenceTags(occurrence)
                    /]
                [/#if]
                [#break]
        [/#switch ]
    [/#if]
[/#macro]
