[#ftl]
[#-- Resources --]
[#assign HAMLET_CONTENTHUB_NODE_RESOURCE_TYPE = "contentnode"]

[#macro aws_contentnode_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local id = formatResourceId(HAMLET_CONTENTHUB_NODE_RESOURCE_TYPE, core.Id)]

    [#assign componentState =
        {
            "Resources" : {
                "contentnode" : {
                    "Id" : id,
                    "Type" : HAMLET_CONTENTHUB_NODE_RESOURCE_TYPE
                }
            },
            "Attributes" : {
                "PATH" : getContextPath(occurrence)
            },
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]
[/#macro]
