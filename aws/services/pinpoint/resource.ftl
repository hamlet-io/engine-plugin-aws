[#ftl]

[#assign AWS_PINPOINT_OUTPUT_MAPPINGS =
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
    resourceType=AWS_PINPOINT_RESOURCE_TYPE
    mappings=AWS_PINPOINT_OUTPUT_MAPPINGS
/]

[#macro createPinpointApp id name
        description=""
        dependencies=[]
        tags={} ]
    [@cfResource
        id=id
        type="AWS::Pinpoint::App"
        properties=
        {
            "Name" : name
        } +
        attributeIfContent(
            "Description",
            description
        ) +
        attributeIfContent(
            "Tags",
            tags,
            getCFResourceTags(tags, true)
        )
        outputs=AWS_PINPOINT_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]
