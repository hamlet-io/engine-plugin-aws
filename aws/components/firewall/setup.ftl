[#ftl]

[#macro aws_firewall_cf_deployment_generationcontract occurrence ]
    [@addDefaultGenerationContract subsets=["template"] /]
[/#macro]

[#macro aws_firewall_cf_deployment occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]

    [#local loggingProfile = getLoggingProfile(occurrence)]

    [#local firewallId = resources["firewall"].Id ]
    [#local firewallName = resources["firewall"].Name ]

    [#local firewallPolicyId = resources["policy"].Id ]
    [#local firewallPolicyName = resources["policy"].Name ]

    [#local firewallLoggingId = resources["firewalllogging"].Id ]

    [#local occurrenceNetwork = getOccurrenceNetwork(occurrence) ]
    [#local networkLink = occurrenceNetwork.Link!{} ]
    [#local networkLinkTarget = getLinkTarget(occurrence, networkLink ) ]

    [#if ! networkLinkTarget?has_content ]
        [@fatal message="Network could not be found" context=networkLink /]
        [#return]
    [/#if]

    [#local networkConfiguration = networkLinkTarget.Configuration.Solution]
    [#local networkResources = networkLinkTarget.State.Resources ]

    [#local subnets = []]
    [#if multiAZ ]
        [#local subnets = getSubnets(core.Tier, networkResources)]
    [#else]
        [#local subnets = getSubnets(core.Tier, networkResources, zones[0].Id )]
    [/#if]

    [@createNetworkFirewall
        id=firewallId
        name=firewallName
        vpcId=networkResources["vpc"].Id
        subnets=subnets
        firewallPolicyId=firewallPolicyId
        tags=getOccurrenceCoreTags(occurrence, core.FullName)
    /]

    [@cfOutput
        formatId(firewallId, INTERFACE_ATTRIBUTE_TYPE),
        {
            "Fn::Join": [
                ",",
                {
                    "Fn::GetAtt": [
                        firewallId,
                        "EndpointIds"
                    ]
                }
            ]
        },
        true
    /]

    [#local loggingS3Prefix = ""]
    [#local loggingDestinationId = ""]

    [#switch solution.Logging.DestinationType ]

        [#case "log"]
            [#local logGroupId = resources["lg"].Id ]
            [#local logGroupName = resources["lg"].Name ]

            [#local loggingDestinationId = logGroupId]

            [@setupLogGroup
                occurrence=occurrence
                logGroupId=logGroupId
                logGroupName=logGroupName
                loggingProfile=loggingProfile
            /]
            [#break]

        [#case "s3"]
            [#local s3LinkTarget = getLinkTarget(occurrence, solution.Logging["destinationType:s3"].Link) ]

            [#switch s3LinkTarget.Core.Type ]
                [#case S3_COMPONENT_TYPE ]
                [#case BASELINE_DATA_COMPONENT_TYPE]
                    [#local loggingDestinationId = (s3LinkTarget.State.Resources["bucket"].Id)!"" ]
                    [#local loggingS3Prefix  = getContextPath(occurrence, solution.Logging["destinationType:s3"].Prefix) ]

                [#default]
                    [@fatal
                        message="Invalid firewall logging destination for destination type"
                        context={
                            "FirewallId" : core.RawId,
                            "DestinationType" : solution.Logging.DestinationType,
                            "LinkComponentType" : s3LinkTarget.Core.Type,
                            "SupportedTypes" : [
                                S3_COMPONENT_TYPE,
                                BASELINE_DATA_COMPONENT_TYPE
                            ]
                        }
                    /]
            [/#switch]
            [#break]

        [#case "datafeed"]
            [#local datafeedLinkTarget = getLinkTarget(occurrence, solution.Logging["destinationType:datafeed"].Link) ]

            [#switch datafeedLinkTarget.Core.Type ]
                [#case DATAFEED_COMPONENT_TYPE ]
                    [#local loggingDestinationId = (datafeedLinkTarget.State.Resources["stream"].Id)!"" ]
                    [#break]

                [#default]
                    [@fatal
                        message="Invalid firewall logging destination for destination type"
                        context={
                            "FirewallId" : core.RawId,
                            "DestinationType" : solution.Logging.DestinationType,
                            "LinkComponentType" : datafeedLinkTarget.Core.Type,
                            "SupportedTypes" : [
                                DATAFEED_COMPONENT_TYPE
                            ]
                        }
                    /]
            [/#switch]
            [#break]
    [/#switch]

    [#local logType = ""]
    [#switch solution.Logging.Events]
        [#case "all"]
            [#local logType = "flow"]
            [#break]

        [#case "alert-only"]
            [#local logType = "alert"]
            [#break]
    [/#switch]

    [#local logConfig = getNetworkFirewallLoggingConfiguration(
                            logType,
                            solution.Logging.DestinationType,
                            loggingDestinationId,
                            loggingS3Prefix)]

    [@createNetworkFirewallLogging
        id=firewallLoggingId
        firewallId=firewallId
        logDestinationConfigs=logConfig
    /]

    [#local statefulRuleGroupIds = []]

    [#local statelessRuleGroupRefs = []]
    [#local statelessDefaultActions = []]
    [#local statelessFragmentDefaultActions = []]
    [#local statelessCustomActions = []]

    [#list (occurrence.Occurrences)![] as subOccurrence ]
        [#local subCore = subOccurrence.Core ]
        [#local subSolution = subOccurrence.Configuration.Solution ]
        [#local subResources = subOccurrence.State.Resources ]

        [#local ruleGroupId = subResources["rulegroup"].Id ]
        [#local ruleGroupName = subResources["rulegroup"].Name ]

        [#local createRuleGroup = true]

        [#local ruleGroupArgs = {
            "httpDomainFilter" : {},
            "statefulComplexRule" : "",
            "statefulSimpleRules" : [],
            "statelessRule" : {},
            "variables" : {}
        }]

        [#switch subSolution.Inspection]
            [#case "Stateful"]
                [#switch subSolution.Type ]
                    [#case "NetworkTuple" ]
                        [#local ruleGroupArgs += {
                            "statefulSimpleRules" : ruleGroupArgs.statefulSimpleRules + getNetworkFirewallRuleGroupSimpleStatefulRules(
                                subSolution.Action,
                                getGroupCIDRs(subSolution.NetworkTuple.Destination.IPAddressGroups),
                                ports[subSolution.NetworkTuple.Destination.Port],
                                getGroupCIDRs(subSolution.NetworkTuple.Source.IPAddressGroups),
                                ports[subSolution.NetworkTuple.Source.Port],
                                "any"
                            )
                        }]
                        [#break]

                    [#case "HostFilter"]
                        [#local domains = subSolution.HostFilter.Hosts ]
                        [#list (subSolution.HostFilter.LinkEndpoints)?values as linkEndpoint ]
                            [#local linkTarget = getLinkTarget(linkEndpoint.Link)]
                            [#if linkTarget?has_content
                                    && ((linkTarget.State.Attributes[linkEndpoint.Attribute])!"")?has_content]
                                [#local domains = combineEntities(
                                                    domains,
                                                    [ linkTarget.State.Attributes[linkEndpoint.Attribute] ],
                                                    MERGE_COMBINE_BEHAVIOUR) ]
                            [/#if]
                        [/#list]

                        [#local hostfilterAction = ""]
                        [#switch subSolution.Action ]
                            [#case "pass"]
                                [#local hostfilterAction = "allow"]
                                [#break]

                            [#case "drop"]
                                [#local hostfilterAction = "deny"]
                                [#break]

                            [#default]
                                [@fatal
                                    message="Invalid action for HostFilter network Rule"
                                    context={
                                        "FirewallId" : core.RawId,
                                        "RuleId" : subCore.RawId,
                                        "Action" : subSolution.Action,
                                        "PermittedActions" : [ "pass", "drop" ]
                                    }
                                /]
                        [/#switch]

                        [#local ruleGroupArgs += {
                            "httpDomainFilter" : getNetworkFirewallRuleGroupHTTPDomainFiltering(
                                hostfilterAction,
                                domains,
                                subSolution.HostFilter.Protocols
                            )
                        }]
                        [#break]

                    [#default]
                        [@fatal
                            message="Stateful rule inspection does not support rule type"
                            context={
                                "FirewallId" : core.RawId,
                                "RuleId" : subCore.RawId,
                                "Type" : subSolution.Type
                            }
                        /]
                [/#switch]
                [#break]

            [#case "Stateless"]
                [#switch subSolution.Type]
                    [#case "NetworkTuple"]

                        [#local statelessAction = ""]
                        [#if subSolution.Priority?is_string && (subSolution.Priority)?lower_case == "default" ]
                            [#local priority = 1 ]
                            [#local statelessAction = subSolution.Action ]

                            [#switch subSolution.Action ]
                                [#case "drop"]
                                    [#local statelessDefaultActions += ["aws:drop"]]
                                    [#break]
                                [#case "pass"]
                                    [#local statelessDefaultActions += ["aws:pass"]]
                                    [#break]
                                [#case "inspect"]
                                    [#local statelessDefaultActions += ["aws:forward_to_sfe"]]
                                    [#break]

                                [#default]
                                    [@fatal
                                        message="Invalid network friewall stateless default action"
                                        context={
                                            "FirewallId" : core.RawId,
                                            "RuleId" : subCore.RawId,
                                            "Action" : subSolution.Action,
                                            "PossibleActions" : [ "drop", "pass", "inspect"]
                                        }
                                    /]
                            [/#switch]

                            [#local createRuleGroup = false ]

                        [#else]
                            [#local priority = subSolution.Priority]
                            [#local statelessRuleGroupRefs += [ getNetworkFirewallPolicyStatelessRuleReference(ruleGroupId, subSolution.Priority)] ]
                            [#local statelessAction = subSolution.Action]

                            [#local ruleGroupArgs += {
                                "statelessRule" : getFirewallRuleGroupStatelessRule(
                                                    priority,
                                                    statelessAction,
                                                    getGroupCIDRs(subSolution.NetworkTuple.Source.IPAddressGroups),
                                                    ports[subSolution.NetworkTuple.Source.Port],
                                                    getGroupCIDRs(subSolution.NetworkTuple.Destination.IPAddressGroups),
                                                    ports[subSolution.NetworkTuple.Destination.Port]
                                                )
                            }]
                        [/#if]
                        [#break]
                [/#switch]
                [#break]
        [/#switch]

        [#if createRuleGroup ]
            [@createNetworkFirewallRuleGroup
                id=ruleGroupId
                name=ruleGroupName
                type=subSolution.Inspection
                capacity=100
                ruleGroup=getNetworkFirewallRuleGroup?with_args(ruleGroupArgs?values)()
                tags=getOccurrenceCoreTags(subOccurrence, subCore.FullName)
            /]
        [/#if]

    [/#list]

    [#if ! statelessDefaultActions?has_content ]
        [@fatal
            message="Missing default stateless action rule - add a stateless rule with default priority"
            context={
                "FirewallId" : core.RawId
            }
        /]
    [/#if]

    [@createNetworkFirewallPolicy
        id=firewallPolicyId
        name=firewallPolicyName
        statefulRuleGroupIds=statefulRuleGroupIds
        statelessRuleGroupRefs=statelessRuleGroupRefs
        statelessCustomActions=statelessCustomActions
        statelessDefaultActions=statelessDefaultActions
        statelessFragmentDefaultActions=
            statelessFragmentDefaultActions?has_content?then(
                statelessFragmentDefaultActions,
                statelessDefaultActions
            )
        tags=getOccurrenceCoreTags(occurrence, core.FullName)
    /]

[/#macro]
