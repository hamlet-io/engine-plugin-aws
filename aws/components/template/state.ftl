[#ftl]

[#macro aws_template_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]

    [#local solution = occurrence.Configuration.Solution]

    [#local templateId = formatResourceId(AWS_CLOUDFORMATION_STACK_RESOURCE_TYPE, core.Id)]

    [#local attributes = {}]
    [#list solution.Attributes as id,attribute ]
        [#local attributes = mergeObjects(
                                attributes,
                                {
                                    attribute.AttributeType?upper_case : getExistingReference(AWS_PROVIDER, templateId, attribute.AttributeType)
                                } )]
    [/#list]

    [#assign componentState =
        {
            "Resources" : {
                "template" : {
                    "Id" : templateId,
                    "Type" : AWS_CLOUDFORMATION_STACK_RESOURCE_TYPE
                }
            },
            "Attributes" : attributes,
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]
[/#macro]
