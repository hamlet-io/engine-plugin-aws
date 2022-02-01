[#ftl]

[#macro aws_globaldb_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local id = formatResourceId(AWS_DYNAMODB_TABLE_RESOURCE_TYPE, core.Id )]
    [#local key = solution.PrimaryKey ]
    [#local sortKey = solution.SecondaryKey ]

    [#local globalSecondaryIndexes = [] ]
    [#list solution.SecondaryIndexes!{} as key,value]
        [#local globalSecondaryIndexes += [value.Name] ]
    [/#list]

    [#assign componentState =
        {
            "Resources" : {
                "table" : {
                    "Id" : id,
                    "Name" : core.FullName,
                    "Key" : key,
                    "Monitored": true,
                    "Type" : AWS_DYNAMODB_TABLE_RESOURCE_TYPE
                } +
                attributeIfContent(
                    "SortKey",
                    sortKey
                )
            },
            "Attributes" : {
                "TABLE_NAME" : getExistingReference(id),
                "TABLE_ARN" : getExistingReference(id, ARN_ATTRIBUTE_TYPE),
                "TABLE_KEY" : key
            } +
            attributeIfContent(
                "TABLE_SORT_KEY",
                sortKey
            ) +
            attributeIfTrue(
                "STREAM_ARN",
                solution.ChangeStream.Enabled,
                getExistingReference(id, EVENTSTREAM_ATTRIBUTE_TYPE)
            ),
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {
                    "default" : "consume",
                    "stream" : arrayIfTrue(
                                    dynamodbStreamRead(
                                        getReference(id, ARN_ATTRIBUTE_TYPE)
                                    ),
                                    solution.ChangeStream.Enabled
                                ),
                    "consume" : dynamoDbViewerPermission(
                                    getReference(id, ARN_ATTRIBUTE_TYPE)
                                ) +
                                arrayIfContent(
                                    dynamoDbViewerPermission(
                                        getReference(id, ARN_ATTRIBUTE_TYPE),
                                        globalSecondaryIndexes
                                    ),
                                    globalSecondaryIndexes
                                ) +
                                arrayIfTrue(
                                    dynamodbStreamRead(
                                        getReference(id, ARN_ATTRIBUTE_TYPE)
                                    ),
                                    solution.ChangeStream.Enabled
                                ),
                    "produce" : dynamodbProducePermission(
                                    getReference(id, ARN_ATTRIBUTE_TYPE)
                                ) +
                                arrayIfContent(
                                    dynamodbProducePermission(
                                        getReference(id, ARN_ATTRIBUTE_TYPE),
                                        "",
                                        {},
                                        globalSecondaryIndexes
                                    ),
                                    globalSecondaryIndexes
                                ),
                    "all"     : dynamodbAllPermission(
                                    getReference(id,ARN_ATTRIBUTE_TYPE)
                                ) +
                                arrayIfContent(
                                    dynamodbAllPermission(
                                        getReference(id, ARN_ATTRIBUTE_TYPE),
                                        globalSecondaryIndexes
                                    ),
                                    globalSecondaryIndexes
                                ) +
                                arrayIfTrue(
                                    dynamodbStreamRead(
                                        getReference(id, ARN_ATTRIBUTE_TYPE)
                                    ),
                                    solution.ChangeStream.Enabled
                                )
               }
            }
        }
    ]
[/#macro]
