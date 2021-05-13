[#ftl]

[#-- Resources --]
[#assign HAMLET_ADAPTOR_RESOURCE_TYPE = "adaptor"]

[#macro aws_adaptor_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local adaptorId = formatResourceId(HAMLET_ADAPTOR_RESOURCE_TYPE, core.Id)]

    [#local attributes = {}]

    [#list solution.Attributes as id,attribute ]
        [#local attributes = mergeObjects(
                                attributes,
                                {
                                    id?upper_case :  getExistingReference(adaptorId, attribute.OutputAttributeType)
                                }
                            )]
    [/#list]


    [#assign componentState =
        {
            "Resources" : {
                "adaptor" : {
                    "Id" : adaptorId,
                    "Type" : HAMLET_ADAPTOR_RESOURCE_TYPE
                }
            },
            "Attributes" : attributes
        }
    ]
[/#macro]
