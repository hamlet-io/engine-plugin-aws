[#ftl]

[#-- Resources --]
[#assign HAMLET_ADAPTOR_RESOURCE_TYPE = "adaptor"]

[#macro aws_adaptor_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local id = formatResourceId(HAMLET_ADAPTOR_RESOURCE_TYPE, core.Id)]
    [#assign componentState =
        {
            "Resources" : {
                "adaptor" : {
                    "Id" : id,
                    "Type" : HAMLET_ADAPTOR_RESOURCE_TYPE
                }
            },
            "Attributes" : {}
        }
    ]
[/#macro]
