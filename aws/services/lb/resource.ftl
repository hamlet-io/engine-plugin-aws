[#ftl]

[#assign LB_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        DNS_ATTRIBUTE_TYPE : {
            "Attribute" : "DNSName"
        },
        NAME_ATTRIBUTE_TYPE : {
            "Attribute" : "LoadBalancerFullName"
        }
    }
]

[#assign ALB_LISTENER_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[#assign ALB_LISTENER_RULE_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[#assign ALB_TARGET_GROUP_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        NAME_ATTRIBUTE_TYPE : {
            "Attribute" : "TargetGroupFullName"
        }
    }
]

[#assign lbMappings =
    {
        AWS_LB_RESOURCE_TYPE : LB_OUTPUT_MAPPINGS,
        AWS_ALB_RESOURCE_TYPE : LB_OUTPUT_MAPPINGS,
        AWS_LB_CLASSIC_RESOURCE_TYPE : LB_OUTPUT_MAPPINGS,
        AWS_LB_APPLICATION_RESOURCE_TYPE : LB_OUTPUT_MAPPINGS,
        AWS_LB_NETWORK_RESOURCE_TYPE : LB_OUTPUT_MAPPINGS,
        AWS_ALB_LISTENER_RESOURCE_TYPE : ALB_LISTENER_OUTPUT_MAPPINGS,
        AWS_ALB_LISTENER_RULE_RESOURCE_TYPE : ALB_LISTENER_RULE_OUTPUT_MAPPINGS,
        AWS_ALB_TARGET_GROUP_RESOURCE_TYPE : ALB_TARGET_GROUP_OUTPUT_MAPPINGS
    }
]

[#list lbMappings as type, mappings]
    [@addOutputMapping
        provider=AWS_PROVIDER
        resourceType=type
        mappings=mappings
    /]
[/#list]

[@addCWMetricAttributes
    resourceType=AWS_LB_CLASSIC_RESOURCE_TYPE
    namespace="AWS/ELB"
    dimensions={
        "LoadBalancerName" : {
            "Output" : {
                "Attribute" : REFERENCE_ATTRIBUTE_TYPE
            }
        }
    }
/]

[@addCWMetricAttributes
    resourceType=AWS_LB_APPLICATION_RESOURCE_TYPE
    namespace="AWS/ApplicationELB"
    dimensions={
        "LoadBalancer" : {
            "Output" : {
                "Attribute" : NAME_ATTRIBUTE_TYPE
            }
        }
    }
/]

[@addCWMetricAttributes
    resourceType=AWS_LB_NETWORK_RESOURCE_TYPE
    namespace="AWS/NetworkELB"
    dimensions={
        "LoadBalancer" : {
            "Output" : {
                "Attribute" : NAME_ATTRIBUTE_TYPE
            }
        }
    }
/]

[@addCWMetricAttributes
    resourceType=AWS_ALB_TARGET_GROUP_RESOURCE_TYPE
    namespace="AWS/ApplicationELB"
    dimensions={
        "LoadBalancer" : {
            "OtherOutput" : {
                "Id" : "lb",
                "Property" : NAME_ATTRIBUTE_TYPE
            }
        },
        "TargetGroup" : {
            "Output" : {
                "Attribute" : NAME_ATTRIBUTE_TYPE
            }
        }
    }
/]

[#macro createALB
    id
    name
    shortName
    tier
    component
    securityGroups
    type
    idleTimeout
    publicEndpoint
    networkResources
    logs=false
    bucket=""]

    [#assign loadBalancerAttributes =
        ( type == "application" )?then(
            [
                {
                    "Key" : "idle_timeout.timeout_seconds",
                    "Value" : idleTimeout?c
                }
            ],
            []
        ) +
        (logs && type == "application")?then(
            [
                {
                    "Key" : "access_logs.s3.enabled",
                    "Value" : "true"
                },
                {
                    "Key" : "access_logs.s3.bucket",
                    "Value" : bucket
                },
                {
                    "Key" : "access_logs.s3.prefix",
                    "Value" : ""
                }
            ],
            []
        ) +
        ( type == "network" )?then(
            [
                {
                    "Key" : "load_balancing.cross_zone.enabled",
                    "Value" : "true"
                }
            ],
            []
        )
    ]

    [@cfResource
        id=id
        type="AWS::ElasticLoadBalancingV2::LoadBalancer"
        properties=
            {
                "Subnets" : getSubnets(tier, networkResources),
                "Scheme" : (publicEndpoint)?then("internet-facing","internal"),
                "Name" : shortName,
                "LoadBalancerAttributes" : loadBalancerAttributes
            } +
            attributeIfTrue(
                "Type",
                type != "application",
                type
            ) +
            attributeIfTrue(
                "SecurityGroups",
                type == "application",
                getReferences(securityGroups)
            )

        tags=getCfTemplateCoreTags(name, tier, component)
        outputs=LB_OUTPUT_MAPPINGS
    /]
[/#macro]

[#macro createALBListener id port albId defaultActions certificateId="" sslPolicy="" ]

    [#if port.Protocol == "SSL" ]
        [#local protocol = "TLS" ]
    [#else]
        [#local protocol = port.Protocol]
    [/#if]

    [#local certificateArn = getExistingReference(certificateId, ARN_ATTRIBUTE_TYPE, getRegion())]
    [#if certificateId?has_content && !(certificateArn?has_content) && ((port.Certificate)!false) ]
        [@fatal
            message="LB Certificate ARN could not be found. Check the certificate exists and is in the correct region."
            context=
                {
                    "CertificateId" : certificateId,
                    "Region" : getRegion()
                }
        /]
    [/#if]

    [@cfResource
        id=id
        type="AWS::ElasticLoadBalancingV2::Listener"
        properties=
            {
                "DefaultActions" : asArray(defaultActions),
                "LoadBalancerArn" : getReference(albId),
                "Port" : port.Port,
                "Protocol" : protocol
            } +
            valueIfTrue(
                {
                    "Certificates" : [
                        {
                            "CertificateArn" : certificateArn
                        }
                    ],
                    "SslPolicy" : sslPolicy
                },
                port.Certificate!false)
        outputs=ALB_LISTENER_OUTPUT_MAPPINGS
    /]
[/#macro]


[#function getTargetGroupTarget targetType targetAddress port="" external=false  ]

    [#local target = {
        "Id" : targetAddress
    }]

    [#if targetType == "lambda" ]
        [#local target += {
            "AvailabilityZone" : "all"
        }]
    [/#if]

    [#if targetType == "ip" && external ]
        [#local target += {
            "AvailabilityZone" : "all"
        }]
    [/#if]

    [#if targetType == "ip" || targetType == "instance" || targetType == "alb" ]
        [#local target += {
            "Port" : port
        }]
    [/#if]

    [#return [ target ]]
[/#function]

[#macro createTargetGroup id name tier component destination attributes vpcId targetType="" targets=[] tags=[] ]

    [#local healthCheckProtocol = getHealthCheckProtocol(destination)?upper_case]

    [#local targetGroupAttributes = [] ]
    [#list attributes as key,value ]
        [#local targetGroupAttributes +=
            [
                {
                    "Key" : key,
                    "Value" : (value?is_string)?then(
                                    value,
                                    value?c
                                )
                }
            ]]
    [/#list]

    [#switch targetType ]
        [#case "aws:alb"]
        [#case "alb"]
            [#local targetType = "alb"]
            [#break]
    [/#switch]

    [@cfResource
        id=id
        type="AWS::ElasticLoadBalancingV2::TargetGroup"
        properties=
            {
                "HealthCheckPort" : (destination.HealthCheck.Port)!"traffic-port",
                "HealthCheckProtocol": healthCheckProtocol,
                "HealthyThresholdCount" : destination.HealthCheck.HealthyThreshold?number,
                "Port" : destination.Port,
                "Protocol" : protocol!((destination.Protocol)?upper_case),
                "VpcId": getReference(vpcId)
            } +
            attributeIfContent(
                "TargetGroupAttributes",
                targetGroupAttributes
            ) +
            valueIfContent(
                {
                    "Matcher" : { "HttpCode" : (destination.HealthCheck.SuccessCodes)!"" }
                },
                (destination.HealthCheck.SuccessCodes)!"") +
            valueIfTrue(
                {
                    "TargetType" : targetType
                },
                targetType == "ip" || targetType == "alb"
            ) +
            valueIfContent(
                {
                    "HealthCheckPath" : (destination.HealthCheck.Path)!""
                },
                (destination.HealthCheck.Path)!""
            ) +
            (destination.Protocol != "TCP")?then(
                {
                    "HealthCheckIntervalSeconds" : destination.HealthCheck.Interval?number,
                    "HealthCheckTimeoutSeconds" : destination.HealthCheck.Timeout?number,
                    "UnhealthyThresholdCount" : destination.HealthCheck.UnhealthyThreshold?number
                },
                {
                    "UnhealthyThresholdCount" : destination.HealthCheck.HealthyThreshold?number
                }

            ) +
            attributeIfContent(
                "Targets",
                targets
            )
        tags=tags
        outputs=ALB_TARGET_GROUP_OUTPUT_MAPPINGS
    /]
[/#macro]

[#function getListenerRuleForwardAction targetGroupId order=""]
    [#return
        [
            {
                "Type": "forward",
                "TargetGroupArn": getReference(targetGroupId, ARN_ATTRIBUTE_TYPE)
            } +
            attributeIfContent("Order", order)
        ]
    ]
[/#function]

[#function getListenerRuleRedirectAction protocol port host path query permanent=true order=""]
    [#return
        [
            {
                "Type": "redirect",
                "RedirectConfig": {
                    "Protocol": protocol,
                    "Port": port,
                    "Host": host,
                    "Path": path?ensure_starts_with("/"),
                    "Query": query,
                    "StatusCode": valueIfTrue("HTTP_301", permanent, "HTTP_302")
                }
            } +
            attributeIfContent("Order", order)
        ]
    ]
[/#function]

[#function getListenerRuleFixedAction message contentType statusCode order=""]
    [#return
        [
            {
                "Type": "fixed-response",
                "FixedResponseConfig": {
                    "MessageBody": message,
                    "ContentType": contentType,
                    "StatusCode": statusCode?is_number?then(
                        statusCode?c,
                        statusCode
                    )
                }
            } +
            attributeIfContent("Order", order)
        ]
    ]
[/#function]

[#function getListenerRuleAuthCognitoAction
        userPoolArn
        userPoolClientId
        userPoolDomain
        userPoolSessionCookieName
        userPoolSessionTimeout
        userPoolOauthScope
        order=""]

    [#return
        [
            {
                "Type" : "authenticate-cognito",
                "AuthenticateCognitoConfig" : {
                    "UserPoolArn" : userPoolArn,
                    "UserPoolClientId" : userPoolClientId,
                    "UserPoolDomain" : userPoolDomain,
                    "SessionCookieName" : userPoolSessionCookieName,
                    "SessionTimeout" : userPoolSessionTimeout,
                    "Scope" : userPoolOauthScope,
                    "OnUnauthenticatedRequest" : "authenticate"
                }
            } +
            attributeIfContent("Order", order)
        ]
    ]
[/#function]

[#function getListenerRuleCondition type conditionValue ]
    [#local result = {
        "Field" : type
    }]

    [#switch type ]
        [#case "http-header" ]
            [#local result += {
                "HttpHeaderConfig" : {
                    "HttpHeaderName" : conditionValue.HeaderName,
                    "Values" : conditionValue.Values
                }
            }]
            [#break]

        [#case "query-string" ]
            [#local result += {
                "QueryStringConfig" : {
                    "Values" : asFlattenedArray(conditionValue)
                }
            }]
            [#break]

        [#case "http-request-method" ]
            [#local result += {
                "HttpRequestMethodConfig" : {
                    "Values"  : asFlattenedArray(conditionValue)
                }
            }]
            [#break]

        [#case "host-header" ]
            [#local result += {
                "HostHeaderConfig" : {
                    "Values" : asFlattenedArray(conditionValue)
                }
            }]
            [#break]

        [#case "path-pattern" ]
            [#local result += {
                "PathPatternConfig" : {
                    "Values" : asFlattenedArray(conditionValue)
                }
            }]
            [#break]

        [#case "source-ip" ]
            [#local result += {
                "SourceIpConfig" : {
                    "Values" : asFlattenedArray(conditionValue)
                }
            }]
            [#break]

        [#default]
            [@fatal
                message="Invalid Application Load balancer Rule Condition"
                context={
                    "Type" : type,
                    "Values" : values
                }
            /]
    [/#switch]
    [#return [ result ]]
[/#function]

[#macro createListenerRule id listenerId actions=[] conditions=[] priority=100 dependencies=""]
    [@cfResource
        id=id
        type="AWS::ElasticLoadBalancingV2::ListenerRule"
        properties=
            {
                "Priority" : priority,
                "Actions" : asArray(actions),
                "Conditions": asArray(conditions),
                "ListenerArn" : getReference(listenerId, ARN_ATTRIBUTE_TYPE)
            }
        outputs=ALB_LISTENER_RULE_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]

[#macro createClassicLB id name shortName tier component
            listeners
            healthCheck
            securityGroups
            idleTimeout
            deregistrationTimeout
            networkResources
            publicEndpoint
            policies=[]
            stickinessPolicies=[]
            logs=false
            bucket=""
            dependencies="" ]
        [@cfResource
        id=id
        type="AWS::ElasticLoadBalancing::LoadBalancer"
        properties=
            {
                "Listeners" : listeners,
                "HealthCheck" : healthCheck,
                "Scheme" :
                    (publicEndpoint)?then(
                        "internet-facing",
                        "internal"
                    ),
                "SecurityGroups": getReferences(securityGroups),
                "LoadBalancerName" : shortName,
                "ConnectionSettings" : {
                    "IdleTimeout" : idleTimeout
                }
            } +
            multiAZ?then(
                {
                    "Subnets" : getSubnets(tier, networkResources),
                    "CrossZone" : true
                },
                {
                    "Subnets" : [ getSubnets(tier, networkResources)[0] ]
                }
            ) +
            (logs)?then(
                {
                    "AccessLoggingPolicy" : {
                        "EmitInterval" : 5,
                        "Enabled" : true,
                        "S3BucketName" : bucket
                    }
                },
                {}
            ) +
            ( deregistrationTimeout > 0 )?then(
                {
                    "ConnectionDrainingPolicy" : {
                        "Enabled" : true,
                        "Timeout" : deregistrationTimeout
                    }
                },
                {}
            ) +
            attributeIfContent(
                "LBCookieStickinessPolicy",
                stickinessPolicies
            ) +
            attributeIfContent(
                "Policies",
                policies
            )
        tags=
            getCfTemplateCoreTags(
                name,
                tier,
                component)
        outputs=LB_OUTPUT_MAPPINGS +
                    {
                        NAME_ATTRIBUTE_TYPE : {
                            "UseRef" : true
                        }
                    }
        dependencies=dependencies
    /]
[/#macro]
