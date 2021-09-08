[#ftl]

[#macro aws_correspondent_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local resources = {}]
    [#local attributes = {}]

    [#local correspondentId = formatResourceId(AWS_PINPOINT_RESOURCE_TYPE, core.Id)]

    [#local resources += {
        "correspondent" : {
            "Id" : correspondentId,
            "Name" : core.FullName,
            "Type" : AWS_PINPOINT_RESOURCE_TYPE
        }
    }]

     [#local attributes += {
        "ARN" : getExistingReference(correspondentId, ARN_ATTRIBUTE_TYPE),
        "APP" : getExistingReference(correspondentId)
    }]

    [#assign componentState =
        {
            "Resources" : resources,
            "Attributes" : attributes
        }
    ]

[/#macro]
