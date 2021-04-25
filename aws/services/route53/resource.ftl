[#ftl]

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
                "HealthCheckTags" : getCfTemplateCoreTags(name)
            }
        outputs=AWS_ROUTE53_HEALTHCHECK_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]
