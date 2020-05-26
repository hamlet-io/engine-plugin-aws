[#ftl]

[#macro aws_router_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local routerId = formatResourceId(AWS_TRANSITGATEWAY_GATEWAY_RESOURCE_TYPE, core.Id) ]
    [#local routeTableId = formatResourceId(AWS_TRANSITGATEWAY_ROUTETABLE_RESOURCE_TYPE, core.Id) ]

    [#assign componentState =
        {
            "Resources" : {
                "transitGateway" : {
                    "Id" : routerId,
                    "Name" : core.FullName,
                    "Type" : AWS_TRANSITGATEWAY_GATEWAY_RESOURCE_TYPE
                },
                "routeTable" : {
                    "Id" : routeTableId,
                    "Name" : core.FullName,
                    "Type" : AWS_TRANSITGATEWAY_ROUTETABLE_RESOURCE_TYPE
                }
            } +
            attributeIfTrue(
                "resourceShare",
                solution["aws:ResourceSharing"].Enabled,
                {
                    "Id" : formatResourceId(AWS_RESOURCEACCESS_SHARE_RESOURCE_TYPE),
                    "Name" : core.FullName,
                    "Type" : AWS_RESOURCEACCESS_SHARE_RESOURCE_TYPE
                }
            ),
            "Attributes" : {
            },
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]
[/#macro]
