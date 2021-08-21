[#ftl]

[#assign AWS_ROUTE53RESOLVER_RESOLVER_LOGGING_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "Attribute" : "Arn"
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_ROUTE53RESOLVER_RESOLVER_LOGGING_RESOURCE
    mappings=AWS_ROUTE53RESOLVER_RESOLVER_LOGGING_OUTPUT_MAPPINGS
/]


[#assign AWS_ROUTE53RESOLVER_RESOLVER_LOGGING_ASSOCIATION_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_ROUTE53RESOLVER_RESOLVER_LOGGING_ASSOCIATION_RESOURCE
    mappings=AWS_ROUTE53RESOLVER_RESOLVER_LOGGING_ASSOCIATION_OUTPUT_MAPPINGS
/]

[#macro createRoute53ResolverLogging
        id
        name
        destinationId
        dependencies=[]
    ]

    [@cfResource
        id=id
        type="AWS::Route53Resolver::ResolverQueryLoggingConfig"
        properties=
            {
                "DestinationArn" : getArn(destinationId),
                "Name" : name
            }
        outputs=AWS_ROUTE53RESOLVER_RESOLVER_LOGGING_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]

[#macro createRoute53ResolverLoggingAssociation
        id
        resolverLoggingId
        vpcId
        dependencies=[]
    ]

    [@cfResource
        id=id
        type="AWS::Route53Resolver::ResolverQueryLoggingConfigAssociation"
        properties=
            {
                "ResolverQueryLogConfigId" : getReference(resolverLoggingId),
                "ResourceId" : getReference(vpcId)
            }
        outputs=AWS_ROUTE53RESOLVER_RESOLVER_LOGGING_ASSOCIATION_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]
