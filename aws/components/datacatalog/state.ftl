[#ftl]

[#macro aws_datacatalog_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local databaseId = formatResourceId(AWS_GLUE_DATABASE_RESOURCE_TYPE, core.Id)]

    [#assign componentState =
        {
            "Resources" : {
                "database" : {
                    "Id" : databaseId,
                    "Name" : replaceAlphaNumericOnly(core.RawFullName, "_"),
                    "Type" : AWS_GLUE_DATABASE_RESOURCE_TYPE
                }
            },
            "Attributes" : {
                "NAME" : getExistingReference(databaseId)
            }
        }
    ]

[/#macro]


[#macro aws_datacatalogtable_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local tableId = formatResourceId(AWS_GLUE_TABLE_RESOURCE_TYPE, core.Id)]

    [#local resources = {
        "table": {
            "Id" : tableId,
            "Name": core.SubComponent.RawName,
            "Type" : AWS_GLUE_TABLE_RESOURCE_TYPE
        }
    }]

    [#if solution.Crawler.Enabled ]
        [#local resources = mergeObjects(
            resources,
            {
                "crawler" : {
                    "Id" : formatResourceId(AWS_GLUE_CRAWLER_RESOURCE_TYPE, core.Id),
                    "Name": core.RawFullName,
                    "Type": AWS_GLUE_CRAWLER_RESOURCE_TYPE
                },
                "crawlerRole": {
                    "Id": formatResourceId(AWS_IAM_RESOURCE_ROLE_TYPE, core.Id, "crawler"),
                    "Type" : AWS_IAM_ROLE_RESOURCE_TYPE
                }
            }
        )]
    [/#if]

    [#assign componentState =
        {
            "Resources" : resources,
            "Attributes" : {
                "NAME": getExistingReference(tableId)
            }
        }
    ]
[/#macro]
