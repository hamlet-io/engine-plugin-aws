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


[#macro aws_correspondentchannel_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local resources = {}]
    [#local attributes = {}]

    [#local correspondentId = formatResourceId(AWS_PINPOINT_RESOURCE_TYPE, core.Id)]

    [#local resourceType = ""]
    [#switch solution.Engine]
        [#case "apns"]
            [#local resourceType = AWS_PINPOINT_APNS_CHANNEL_RESOURCE_TYPE]
            [#break]
        [#case "apns_sanbox"]
            [#local resourceType = AWS_PINPOINT_APNS_SANDBOX_CHANNEL_RESOURCE_TYPE]
            [#break]
        [#case "firebase"]
            [#local resourceType = AWS_PINPOINT_GCM_CHANNEL_RESOURCE_TYPE]
            [#break]
    [/#switch]

    [#assign componentState =
        {
            "Resources" : {
                "channel": {
                    "Id" : formatResourceId(resourceType, core.Id),
                    "Type" : resourceType
                }
            },
            "Attributes" : {}
        }
    ]
[/#macro]
