[#ftl]

[#assign AWS_NETWORK_FIREWALL_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
             "UseRef" : true
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_NETWORK_FIREWALL_RESOURCE_TYPE
    mappings=AWS_NETWORK_FIREWALL_OUTPUT_MAPPINGS
/]

[@addCWMetricAttributes
    resourceType=AWS_NETWORK_FIREWALL_RESOURCE_TYPE
    namespace="AWS/NetworkFirewall"
    dimensions={
        "FirewallName" : {
            "ResourceProperty" : "Name"
        }
    }
/]

[#assign AWS_NETWORK_FIREWALL_POLICY_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
             "UseRef" : true
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_NETWORK_FIREWALL_POLICY_RESOURCE_TYPE
    mappings=AWS_NETWORK_FIREWALL_POLICY_OUTPUT_MAPPINGS
/]

[#assign AWS_NETWORK_FIREWALL_LOGGING_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_NETWORK_FIREWALL_LOGGING_RESOURCE_TYPE
    mappings=AWS_NETWORK_FIREWALL_LOGGING_OUTPUT_MAPPINGS
/]

[#assign AWS_NETWORK_FIREWALL_RULEGROUP_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "Attribute" : "RuleGroupArn"
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_NETWORK_FIREWALL_RULEGROUP_RESOURCE_TYPE
    mappings=AWS_NETWORK_FIREWALL_RULEGROUP_OUTPUT_MAPPINGS
/]

[#macro createNetworkFirewall id name
        vpcId
        subnets
        firewallPolicyId
        tags={}
        description=""
        dependencies=[] ]

    [@cfResource
        id=id
        type="AWS::NetworkFirewall::Firewall"
        properties={
            "VpcId" : getReference(vpcId),
            "FirewallName" : name,
            "FirewallPolicyArn" : getArn(firewallPolicyId),
            "SubnetMappings" : asArray(subnets)?map( subnetId -> { "SubnetId" : subnetId})
        } +
        attributeIfContent(
            "Description",
            description
        )
        tags=tags
        outputs=AWS_NETWORK_FIREWALL_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]

[#function getNetworkFirewallPolicyStatelessRuleReference id priority=100 ]
    [#return
        {
            "ResourceArn" : getArn(id),
            "Priority" : priority
        }
    ]
[/#function]

[#function getNetworkFirewallPolicyStatelessCustomAction name type metricDimensions ]
    [#return
        {
            "ActionName" : name,
            "ActionDefinition" : {} +
            attributeIfTrue(
                "PublishMetricAction",
                (type == "metric"),
                {
                    "Dimensions" : asArray(metricDimensions)?map(dimension -> { "Value" : dimension })
                }
            )
        }
    ]
[/#function]

[#macro createNetworkFirewallPolicy id name
        statefulRuleGroupIds=[]
        statelessRuleGroupRefs=[]
        statelessCustomActions=[]
        statelessDefaultActions=[]
        statelessFragmentDefaultActions=[]
        tags={}
        description=""
        dependencies=[] ]

    [@cfResource
        id=id
        type="AWS::NetworkFirewall::FirewallPolicy"
        properties={
            "FirewallPolicyName" : name,
            "FirewallPolicy" : {} +
                attributeIfContent(
                    "StatefulRuleGroupReferences",
                    statefulRuleGroupIds,
                    asArray(statefulRuleGroupIds)?map(ruleId -> { "ResourceArn" : getArn(ruleId)})
                ) +
                attributeIfContent(
                    "StatelessRuleGroupReferences",
                    asArray(statelessRuleGroupRefs)
                ) +
                attributeIfContent(
                    "StatelessCustomActions",
                    asArray(statelessCustomActions)
                ) +
                attributeIfContent(
                    "StatelessDefaultActions",
                    statelessDefaultActions,
                    asArray(statelessDefaultActions)
                ) +
                attributeIfContent(
                    "StatelessFragmentDefaultActions",
                    asArray(statelessFragmentDefaultActions)
                )
        } +
        attributeIfContent(
            "Description",
            description
        )
        tags=tags
        outputs=AWS_NETWORK_FIREWALL_POLICY_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]

[#function getNetworkFirewallLoggingConfiguration logType destinationType destinationId s3Prefix ]

    [#local logDestination = {}]

    [#switch destinationType ]
        [#case "log" ]
            [#local destinationType = "CloudWatchLogs"]
            [#local logDestination = {
                "logGroup" : getReference(destinationId)
            }]
            [#break]
        [#case "datafeed" ]
            [#local destinationType = "KinesisDataFirehose"]
            [#local logDestination = {
                "deliveryStream" : getReference(destinationId, NAME_ATTRIBUTE_TYPE)
            }]
            [#break]
        [#case "s3"]
            [#local destinationType = "S3"]
            [#local logDestination = {
                "bucketName" : getReference(destinationId, NAME_ATTRIBUTE_TYPE),
                "prefix" : formatRelativePath(s3Prefix)
            }]
            [#break]
        [#default]
            [@fatal
                message="Invalid network firewall logging destination type"
                context={
                    "provided" : destinationType
                }
            /]
    [/#switch]

    [#switch logType?upper_case ]
        [#case "FLOW"]
        [#case "ALERT"]
            [#local logType = logType?upper_case]
            [#break]

        [#default]
            [@fatal
                message="Invalid network firewall log type"
                context={
                    "provided" : logType
                }
            /]
    [/#switch]

    [#return
        {
            "LogDestinationType" : destinationType,
            "LogType" : logType,
            "LogDestination" : logDestination
        }
    ]
[/#function]

[#macro createNetworkFirewallLogging id
        firewallId
        logDestinationConfigs
        dependencies=[]]
    [@cfResource
        id=id
        type="AWS::NetworkFirewall::LoggingConfiguration"
        properties={
            "FirewallArn" : getArn(firewallId),
            "LoggingConfiguration" : {
                "LogDestinationConfigs" : asArray(logDestinationConfigs)
            }
        }
        outputs=AWS_NETWORK_FIREWALL_LOGGING_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]

[#function getNetworkFirewallRuleGroupHTTPDomainFiltering action domains protocols ]

    [#-- Used in RulesSource.RulesSourceList  --]

    [#switch action?lower_case ]
        [#case "allow" ]
        [#case "allowlist"]
            [#local action = "ALLOWLIST"]
            [#break]

        [#case "deny" ]
        [#case "denylist" ]
            [#local action = "DENYLIST"]
            [#break]

        [#default]
            [@fatal
                message="Network firewall HTTP domain rule action invalid"
                context={
                    "provided" : action,
                    "supported" : [ "allow", "deny" ]
                }
            /]
    [/#switch]

    [#local targetTypes = []]
    [#list protocols as protocol ]
        [#switch protocol?lower_case ]
            [#case "http" ]
            [#case "http_host" ]
                [#local targetTypes += [
                    "HTTP_HOST"
                ]]
                [#break]

            [#case "https"]
            [#case "tls_sni"]
                [#local targetTypes += [
                    "TLS_SNI"
                ]]
                [#break]
            [#default]
                [@fatal
                    message="Network firewall HTTP domain protocol invalid"
                    context={
                        "provided" : protocol,
                        "supported" : [ "http", "https" ]
                    }
                /]
        [/#switch]
    [/#list]

    [#local domainNames = [] ]
    [#list domains as domain ]
        [#if domain?starts_with("*")]
            [#local domainNames += [
                domain?remove_beginning("*")?ensure_starts_with(".")
            ]]
        [#else]
            [#local domainNames += [
                domain
            ]]
        [/#if]
    [/#list]

    [#return {
      "GeneratedRulesType" : action,
      "Targets" : asFlattenedArray(domainNames),
      "TargetTypes" : targetTypes
    }]
[/#function]

[#function getNetworkFirewallRuleGroupPort port ]

    [#if ( port?is_string && port == "any")
            || ( port.PortRange.Configured && port.PortRange.From == 0 && port.PortRange.To == 65535 ) ]
        [#return "ANY"]
    [/#if]

    [#if port.PortRange.Configured ]
        [#return (port.PortRange.From)?c + ":" + (port.PortRange.To)?c ]
    [/#if]
    [#return (port.Port)?c ]
[/#function]

[#function getNetworkFirewallRuleGroupSimpleStatefulRules action destinations destinationPort sources sourcePort priority direction="any" ruleOptions=[] ]
    [#local result = []]
    [#list destinations as destination ]
        [#list sources as source ]

            [#local srcdstRuleOptions = combineEntities(ruleOptions,[{
                "Keyword" : "sid",
                "Settings" : [ "${priority}${destination?index}${source?index}" ]
            }],
            APPEND_COMBINE_BEHAVIOUR)]

            [#local result +=
                [
                    {
                        "Action" : action?upper_case,
                        "RuleOptions" : srcdstRuleOptions,
                        "Header" : {
                            "Destination" : destination,
                            "DestinationPort" : getNetworkFirewallRuleGroupPort(destinationPort),
                            "Source" : source,
                            "SourcePort" : getNetworkFirewallRuleGroupPort(sourcePort),
                            "Protocol" : (destinationPort.IPProtocol)?upper_case,
                            "Direction" : direction?upper_case
                        }
                    }
                ]
            ]

        [/#list]
    [/#list]

    [#return result]
[/#function]

[#function getFirewallRuleGroupStatelessRule priority actions sources=[] sourcePorts=[] destinations=[] destinationPorts=[] tcpFlags=[] ]
    [#local actionList = []]
    [#list asArray(actions) as action]
        [#switch action?lower_case ]
            [#case "pass"]
            [#case "aws:pass"]
                [#local actionList += [ "aws:pass" ]]
                [#break]

            [#case "drop"]
            [#case "aws:drop"]
                [#local actionList += [ "aws:drop"]]
                [#break]

            [#case "inspect"]
            [#case "aws:forward_to_sfe"]
                [#local actionList += [ "aws:forward_to_sfe"]]
                [#break]

            [#default]
                [#if action?lower_case?starts_with("custom:")]
                    [#local actionList += [ action?remove_beginning("custom:")]]
                [#else]
                    [@fatal
                        message="Invalid network firewall stateless rule action"
                        context={
                            "provided" : action
                        }
                    /]
                [/#if]
        [/#switch]
    [/#list]

    [#return
        {
            "Priority" : priority,
            "RuleDefinition" : {
                "Actions" : actionList,
                "MatchAttributes" : {} +
                attributeIfContent(
                    "DestinationPorts",
                    destinationPorts,
                    asArray(destinationPorts)?map( port -> { "FromPort" : port.PortRange.From, "ToPort" : port.PortRange.To })
                ) +
                attributeIfContent(
                    "Destinations",
                    asFlattenedArray(destinations)?map( cidr -> { "AddressDefinition" : cidr })
                ) +
                attributeIfContent(
                    "Protocols",
                    destinationPorts,
                    getUniqueArrayElements(
                        asArray(destinationPorts)?map( dstPort -> getIANAIPProtocolNumber(dstPort))
                    )
                ) +
                attributeIfContent(
                    "SourcePorts",
                    sourcePorts,
                    asArray(sourcePorts)?map( port -> { "FromPort" : port.PortRange.From, "ToPort" : port.PortRange.To })
                ) +
                attributeIfContent(
                    "Sources",
                    asFlattenedArray(sources)?map( cidr -> {"AddressDefinition" : cidr })
                ) +
                attributeIfContent(
                    "TCPFlags",
                    asArray(tcpFlags)
                )
            }
        }
    ]
[/#function]

[#function getNetworkFirewallRuleGroup httpDomainFilter={} statefulComplexRule="" statefulSimpleRules=[] statelessRules=[] variables={} customActions=[]]
    [#return
        {
            "RulesSource" : {} +
                attributeIfContent(
                    "RulesSourceList",
                    httpDomainFilter
                ) +
                attributeIfContent(
                    "RulesString",
                    statefulComplexRule
                ) +
                attributeIfContent(
                    "StatefulRules",
                    asArray(statefulSimpleRules)
                ) +
                attributeIfTrue(
                    "StatelessRulesAndCustomActions",
                    (statelessRules?has_content || customActions?has_content),
                    {} +
                    attributeIfContent(
                        "StatelessRules",
                        statelessRules,
                        asArray(statelessRules)
                    ) +
                    attributeIfContent(
                        "CustomActions",
                        customActions,
                        asArray(customActions)
                    )

                )
        } +
        attributeIfContent(
            "RuleVariables",
            variables
        )
    ]
[/#function]

[#macro createNetworkFirewallRuleGroup id name
        type
        capacity
        ruleGroup={}
        description=""
        tags=[]
        dependencies=[] ]

    [@cfResource
        id=id
        type="AWS::NetworkFirewall::RuleGroup"
        properties={
            "Capacity" : capacity?number,
            "RuleGroupName" : name,
            "Type" : type?upper_case
        } +
        attributeIfContent(
            "Description",
            description
        ) +
        attributeIfContent(
            "RuleGroup",
            ruleGroup
        )
        outputs=AWS_NETWORK_FIREWALL_RULEGROUP_OUTPUT_MAPPINGS
        dependencies=dependencies
        tags=tags
    /]
[/#macro]
