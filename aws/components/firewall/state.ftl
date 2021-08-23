[#ftl]

[#macro aws_firewall_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local resources = {}]
    [#local attributes = {}]

    [#switch (solution.Engine)!"" ]
        [#case "network" ]

            [#local firewallId = formatResourceId(AWS_NETWORK_FIREWALL_RESOURCE_TYPE, core.Id)]

            [#local resources += {
                "firewall" : {
                    "Id" : firewallId,
                    "Name" : core.FullName,
                    "Type" : AWS_NETWORK_FIREWALL_RESOURCE_TYPE
                },
                "firewalllogging" : {
                    "Id" : formatResourceId(AWS_NETWORK_FIREWALL_LOGGING_RESOURCE_TYPE, core.Id),
                    "Type" : AWS_NETWORK_FIREWALL_LOGGING_RESOURCE_TYPE
                },
                "policy" : {
                    "Id" : formatResourceId(AWS_NETWORK_FIREWALL_POLICY_RESOURCE_TYPE, core.Id),
                    "Name" : core.FullName,
                    "Type" : AWS_NETWORK_FIREWALL_POLICY_RESOURCE_TYPE
                }
            }]

            [#if solution.Logging.DestinationType == "log"]
                [#local resources += {
                    "lg" : {
                        "Id" : formatDependentLogGroupId(firewallId),
                        "Name" : core.FullAbsolutePath
                    }
                }]
            [/#if]

            [#local attributes += {
                "ARN" : getExistingReference(firewallId, ARN_ATTRIBUTE_TYPE),
                "INTERFACES" : getExistingReference(firewallId, INTERFACE_ATTRIBUTE_TYPE)
            }]

            [#break]

        [#default]
            [@fatal
                message="Unsupported Firewall engine type"
                context={
                    "Id" : core.RawId,
                    "Engine" : (solution.Engine)!""
                }
            /]
    [/#switch]


    [#assign componentState =
        {
            "Resources" : resources,
            "Attributes" : attributes,
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]

[/#macro]


[#macro aws_firewallrule_cf_state occurrence parent={} ]
    [#local parentCore = parent.Core]
    [#local parentSolution = parent.Configuration.Solution]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local resources = {}]
    [#local attributes = {}]

    [#switch parentSolution.Engine ]
        [#case "network"]
            [#switch solution.Type]
                [#case "NetworkTuple"]
                [#case "HostFilter"]
                [#case "Complex"]
                    [#local resources += {
                        "rulegroup" : {
                            "Id" : formatResourceId(AWS_NETWORK_FIREWALL_RULEGROUP_RESOURCE_TYPE, core.Id),
                            "Name" : core.FullName,
                            "Type" : AWS_NETWORK_FIREWALL_RULEGROUP_RESOURCE_TYPE
                        }
                    }]
                    [#break]

                [#default]
                    [@fatal
                        message="Network Engine doens't support the provided rule type"
                        context={
                            "FirewallId" : parentCore.RawId,
                            "Engine" : parentSolution.Engine,
                            "RuleId" : core.RawId,
                            "RuleType" : solution.Type
                        }
                    /]

            [/#switch]
            [#break]

        [#default]
            [@fatal
                message="Firewall engine not supported on aws provider"
                context={
                    "FirewallId" : parentCore.RawId,
                    "Engine" : parentSolution.Engine
                }
            /]
    [/#switch]

    [#assign componentState =
        {
            "Resources" : resources,
            "Attributes" : attributes,
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]
[/#macro]
