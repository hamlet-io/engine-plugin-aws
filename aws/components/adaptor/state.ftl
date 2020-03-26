[#ftl]

[#-- Resources --]
[#assign COT_ADAPTOR_RESOURCE_TYPE = "adaptor"]

[#macro aws_adaptor_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local id = formatResourceId(COT_ADAPTOR_RESOURCE_TYPE, core.Id)]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "OpsData" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local operationsBucket = getExistingReference(baselineComponentIds["OpsData"]) ]

    [#assign componentState =
        {
            "Resources" : {
                "adaptor" : {
                    "Id" : id,
                    "Type" : COT_ADAPTOR_RESOURCE_TYPE
                }
            },
            "Attributes" : {}
        }
    ]
[/#macro]
