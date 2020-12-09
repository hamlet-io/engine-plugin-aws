[#ftl]

[#macro aws_globaldb_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local id = formatResourceId(AWS_DYNAMODB_TABLE_RESOURCE_TYPE, core.Id )]
    [#local key = solution.PrimaryKey ]
    [#local sortKey = solution.SecondaryKey ]

    [#assign componentState =
        {
            "Resources" : {
                "table" : {
                    "Id" : id,
                    "Name" : core.FullName,
                    "Key" : key,
                    "Type" : AWS_DYNAMODB_TABLE_RESOURCE_TYPE
                } +
                attributeIfContent(
                    "SortKey",
                    sortKey
                )
            },
            "Attributes" : {
                "TABLE_NAME" : getExistingReference(AWS_PROVIDER, id),
                "TABLE_ARN" : getExistingReference(AWS_PROVIDER, id, ARN_ATTRIBUTE_TYPE),
                "TABLE_KEY" : key
            } +
            attributeIfContent(
                "TABLE_SORT_KEY",
                sortKey
            ),
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {
                    "default" : "consume",
                    "consume" : dynamoDbViewerPermission(
                                    getReference(AWS_PROVIDER, id, ARN_ATTRIBUTE_TYPE)
                                ),
                    "produce" : dynamodbProducePermission(
                                    getReference(AWS_PROVIDER, id, ARN_ATTRIBUTE_TYPE)
                                ),
                    "all"     : dynamodbAllPermission(
                                    getReference(AWS_PROVIDER, id,ARN_ATTRIBUTE_TYPE)
                                )
               }
            }
        }
    ]
[/#macro]
