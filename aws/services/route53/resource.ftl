[#ftl]

[#-- Route53 Healthcheck --]

[#assign AWS_ROUTE53_HEALTHCHECK_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_ROUTE53_HEALTHCHECK_RESOURCE_TYPE
    mappings=AWS_ROUTE53_HEALTHCHECK_OUTPUT_MAPPINGS
/]

[@addCWMetricAttributes
    resourceType=AWS_ROUTE53_HEALTHCHECK_RESOURCE_TYPE
    namespace="AWS/Route53"
    dimensions={
        "HealthCheckId" : {
            "Output" : {
                "Attribute" : REFERENCE_ATTRIBUTE_TYPE
            }
        }
    }
/]


[#macro createRoute53HealthCheck
        id
        name
        port
        address
        addressType
        regions=[]
        searchString=""
        dependencies=[]
        tags={}
    ]

    [#local availableRegions = [
        "us-east-1",
        "us-west-1",
        "us-west-2",
        "eu-west-1",
        "ap-southeast-1",
        "ap-southeast-2",
        "ap-northeast-1",
        "sa-east-1"
    ]]

    [#local selectedRegions = regions?filter(x -> availableRegions?seq_contains(x))]

    [#if (selectedRegions)?size lt 3 ]
        [@fatal
            message="A minimum of 3 check regions required for health check"
            context={
                "ProvidedRegions" : regions,
                "AvaiableRegions" : availableRegions,
                "SelectedRegions" : selectedRegions
            }
        /]
    [/#if]

    [#local healthCheckConfig = {
        "Port" : port.Port,
        "FailureThreshold" : (port.HealthCheck.UnhealthyThreshold)?number,
        "RequestInterval" : (port.HealthCheck.Interval)?number
    } +
    attributeIfTrue(
        "IPAddress",
        (addressType == "IP"),
        address
    ) +
    attributeIfTrue(
        "FullyQualifiedDomainName",
        (addressType == "Hostname" ),
        address
    ) +
    attributeIfContent(
        "Regions",
        selectedRegions
    )]

    [#switch (port.Protocol)?upper_case ]
        [#case "TCP" ]
            [#local healthCheckConfig += {
                "Type" : "TCP"
            }]
            [#break]

        [#case "HTTP" ]
            [#if searchString?has_content ]
                [#local healthCheckConfig += {
                    "Type" : "HTTP_STR_MATCH",
                    "SearchString" : searchString
                }]
            [#else]
                [#local healthCheckConfig += {
                    "Type" : "HTTP"
                }]
            [/#if]

            [#local healthCheckConfig += {
                "ResourcePath" : port.HealthCheck.Path
            }]
            [#break]

        [#case "HTTPS"]
            [#if searchString?has_content ]
                [#local healthCheckConfig += {
                    "Type" : "HTTPS_STR_MATCH",
                    "SearchString" : searchString
                }]
            [#else]
                [#local healthCheckConfig += {
                    "Type" : "HTTPS"
                }]
            [/#if]

            [#local healthCheckConfig += {
                "ResourcePath" : port.HealthCheck.Path,
                "EnableSNI" : true
            }]
            [#break]

        [#default]
            [@fatal
                message="Unsupported protocol for route53 health checks"
                detail=port.Protocol
                contex={
                    "HealthCheckId" : id,
                    "Port" : port
                }
            /]
    [/#switch]

    [@cfResource
        id=id
        type="AWS::Route53::HealthCheck"
        properties=
            {
                "HealthCheckConfig" : healthCheckConfig,
                "HealthCheckTags" : getCFResourceTags(tags)
            }
        outputs=AWS_ROUTE53_HEALTHCHECK_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]



[#--- Route53 Resolver Endpoint --]

[#assign AWS_ROUTE53_RESOLVER_ENDPOINT_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "Attribute" : "ResolverEndpointId"
        },
        ARN_ATTRIBUTE_TYPE : {
            "Attribute" : "Arn"
        },
        NAME_ATTRIBUTE_TYPE : {
            "Attribute" : "Name"
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_ROUTE53_RESOLVER_ENDPOINT_RESOURCE_TYPE
    mappings=AWS_ROUTE53_RESOLVER_ENDPOINT_OUTPUT_MAPPINGS

/]

[#function getResolverIPAddress subnetId ipAddress=""  ]
    [#return
        {
            "SubnetId" : subnetId
        } +
        attributeIfContent(
            "Ip",
            ipAddress
        )
    ]
[/#function]


[#macro createRoute53ResolverEndpoint
        id
        name
        direction
        resolverIPAddresses
        securityGroupIds
        tags={}
        dependencies=[] ]

    [@cfResource
        id=id
        type="AWS::Route53Resolver::ResolverEndpoint"
        properties={
            "Direction" : direction?upper_case,
            "IpAddresses" : resolverIPAddresses,
            "Name" : name,
            "SecurityGroupIds" : getReferences(securityGroupIds),
            "Tags" : tags
        }
        tags=tags
        outputs=AWS_ROUTE53_RESOLVER_ENDPOINT_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]


[#-- Route53 Resolver Rule --]

[#assign AWS_ROUTE53_RESOLVER_RULE_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "Attribute" : "ResolverRuleId"
        },
        ARN_ATTRIBUTE_TYPE : {
            "Attribute" : "Arn"
        },
        NAME_ATTRIBUTE_TYPE : {
            "Attribute" : "Name"
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_ROUTE53_RESOLVER_RULE_RESOURCE_TYPE
    mappings=AWS_ROUTE53_RESOLVER_RULE_OUTPUT_MAPPINGS

/]

[#function getResolverRuleTargetIp ipAddress port ]
    [#return
        {
            "Ip" : ipAddress,
            "Port" : port.Port
        }
    ]
[/#function]

[#macro createRoute53ResolverRule
        id
        name
        domainName
        resolverEndpointId
        ruleType
        tags={}
        targetIps=[]
        dependencies=[]
    ]

    [@cfResource
        id=id
        type="AWS::Route53Resolver::ResolverRule"
        properties={
            "DomainName" : domainName,
            "Name" : name,
            "ResolverEndpointId" : getReference(resolverEndpointId),
            "RuleType" : ruleType
        } +
        attributeIfContent(
            "TargetIps"
            targetIps
        )
        outputs=AWS_ROUTE53_RESOLVER_RULE_OUTPUT_MAPPINGS
        dependencies=dependencies
        tags=tags
    /]
[/#macro]


[#-- Route53 Resolver Rule Association --]
[#assign AWS_ROUTE53_RESOLVER_RULE_ASSOC_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "Attribute" : "ResolverRuleAssociationId"
        },
        NAME_ATTRIBUTE_TYPE : {
            "Attribute" : "Name"
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_ROUTE53_RESOLVER_RULE_ASSOC_RESOURCE_TYPE
    mappings=AWS_ROUTE53_RESOLVER_RULE_ASSOC_OUTPUT_MAPPINGS
/]

[#macro createRoute53ResolverRuleAssociation
        id
        name
        resolverRuleId
        vpcId
        dependencies=[]
    ]

    [@cfResource
        id=id
        type="AWS::Route53Resolver::ResolverRuleAssociation"
        properties={
            "Name" : name,
            "ResolverRuleId" : getReference(resolverRuleId),
            "VPCId" : getReference(vpcId)
        }
        outputs=AWS_ROUTE53_RESOLVER_RULE_ASSOC_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]


[#-- Route53 Hosted Zone --]
[#assign AWS_ROUTE53_HOSTED_ZONE_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef": true
        },
        REGION_ATTRIBUTE_TYPE: {
            "Value" : { "Ref" : "AWS::Region" }
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_ROUTE53_HOSTED_ZONE_RESOURCE_TYPE
    mappings=AWS_ROUTE53_HOSTED_ZONE_OUTPUT_MAPPINGS
/]

[#function getRoute53HostedZoneVPC vpcId ]
    [#return
        {
            "VPCId": getReference(vpcId),
            "VPCRegion": getReference(vpcId, REGION_ATTRIBUTE_TYPE)
        }
    ]
[/#function]

[#macro createRoute53HostedZone
        id
        name
        vpcIds=[]
        dependencies=[]
        tags={}
    ]
    [#local vpcs = []]
    [#list vpcIds as vpcId ]
        [#local vpcs += [ getRoute53HostedZoneVPC(vpcId) ]]
    [/#list]

    [@cfResource
        id=id
        type="AWS::Route53::HostedZone"
        properties={
            "Name" : name
        } +
        attributeIfContent(
            "HostedZoneTags",
            getCFResourceTags(tags)
        ) +
        attributeIfContent(
            "VPCs",
            vpcs
        )
        dependencies=dependencies
        outputs=AWS_ROUTE53_HOSTED_ZONE_OUTPUT_MAPPINGS
    /]
[/#macro]
