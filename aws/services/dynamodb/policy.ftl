[#ftl]

[#--
Usage Note:

Where a method permits the provision of streams or indexes, it should be noted that separate calls
need to be made to grant permissions on the table itself (with no streams or indexes provided) and
to the streams or indexes themselves.

It is thus possible to grant permission to a stream or index without granting access to the table
itself.
--]

[#function getDynamodbStatement actions tables=[] streams=[] indexes=[] principals="" conditions={} ]
    [#local result = [] ]
    [#if tables?has_content]
        [#list asArray(tables) as table]
            [#if table?is_hash || table?starts_with("arn:") ]
                [#local tableArn = table ]
            [#else]
                [#local tableArn = formatRegionalArn(
                                        "dynamodb",
                                        formatRelativePath("table", table)
                                    )]
            [/#if]

            [#if !(streams?has_content || indexes?has_content)]
                [#local result +=
                    [
                        getPolicyStatement(
                            actions,
                            tableArn,
                            principals,
                            conditions)
                    ]
                ]
            [#else]
                [#list asArray(streams) as stream]
                    [#local result +=
                        [
                            getPolicyStatement(
                                actions,
                                formatRelativePath(tableArn, "stream", stream)
                                principals,
                                conditions)
                        ]
                    ]
                [/#list]
                [#list asArray(indexes) as index]
                    [#local result +=
                        [
                            getPolicyStatement(
                                actions,
                                formatRelativePath(tableArn, "index", index),
                                principals,
                                conditions)
                        ]
                    ]
                [/#list]
            [/#if]
        [/#list]
    [#else]
        [#local result +=
            [
                getPolicyStatement(
                    actions,
                    "*",
                    principals,
                    conditions)
            ]
        ]
    [/#if]
    [#return result]
[/#function]

[#function getDynamoDbItemCondition keys=[] attributes=[] ]
    [#return
        {
            "ForAllValues:StringEquals" : {
            } +
            attributeIfContent(
                "dynamodb:LeadingKeys",
                keys,
                asArray(keys)
            ) +
            attributeIfContent(
                "dynamodb:Attributes",
                attributes,
                asArray(attributes)
            )
        }
    ]
[/#function]

[#function dynamodbReadPermission tables="*"  principals="" conditions={} ]
    [#return
        getDynamodbStatement(
            [
                "dynamodb:BatchGetItem",
                "dynamodb:DescribeTable",
                "dynamodb:GetItem",
                "dynamodb:DescribeTimeToLive",
                "dynamodb:ListTagsOfResource"
            ],
            tables,
            [],
            [],
            principals,
            conditions) +
        valueIfTrue(
            getDynamodbStatement(
                [
                    "dynamodb:ListTables"
                ],
                "",
                [],
                [],
                principals,
                conditions),
            (tables?is_string && tables == "*"),
            []
        )]
[/#function]

[#function dynamodbWritePermission tables="*"  principals="" conditions={} ]
    [#return
        getDynamodbStatement(
            [
                "dynamodb:BatchWriteItem",
                "dynamodb:PutItem",
                "dynamodb:UpdateItem",
                "dynamodb:TagResource",
                "dynamodb:UntagResource"
            ],
            tables,
            [],
            [],
            principals,
            conditions)]
[/#function]

[#function dynamodbDeletePermission tables="*" principals="" conditions={} ]
    [#return
        getDynamodbStatement(
            [
                "dynamodb:DeleteItem"
            ],
            tables,
            [],
            [],
            principals,
            conditions)]
[/#function]

[#function dynamoDbUpdatePermission tables="*" principals="" conditions={}]
    [#return
        getDynamodbStatement(
            [
                "dynamodb:UpdateItem"
            ],
            tables,
            [],
            [],
            principals,
            conditions)]
[/#function]

[#function dynamodbQueryPermission tables="*" indexes=[] principals="" conditions={} ]
    [#return
        getDynamodbStatement(
            [
                "dynamodb:Query"
            ],
            tables,
            [],
            indexes,
            principals,
            conditions)]
[/#function]

[#function dynamodbScanPermission tables="*" indexes=[] principals="" conditions={} ]
    [#return
        getDynamodbStatement(
            [
                "dynamodb:Scan"
            ],
            tables,
            [],
            indexes,
            principals,
            conditions)]
[/#function]

[#-- position of indexes parameter based on ensuring backwards compatability when it was added --]
[#function dynamodbProducePermission tables="*" principals="" conditions={} indexes=[] ]
    [#return
        arrayIfTrue(
            [#-- Table permissions only if no indexes specified --]
            dynamodbReadPermission(
                tables,
                principals,
                conditions
                ) +
            dynamodbWritePermission(
                tables,
                principals,
                conditions),
            !indexes?has_content
        ) +
        dynamodbQueryPermission(
            tables,
            indexes,
            principals,
            conditions) +
        dynamodbScanPermission(
            tables,
            indexes,
            principals,
            conditions)
    ]
[/#function]

[#-- position of indexes parameter based on ensuring backwards compatability when it was added --]
[#function dynamodbConsumePermission tables="*" principals="" conditions={} indexes=[] ]
    [#return
        arrayIfTrue(
            [#-- Table permissions only if no indexes specified --]
            dynamodbReadPermission(
                tables,
                principals,
                conditions) +
            dynamodbDeletePermission(
                tables,
                principals,
                conditions),
            !indexes?has_content
        ) +
        dynamodbQueryPermission(
            tables,
            indexes,
            principals,
            conditions) +
        dynamodbScanPermission(
            tables,
            indexes,
            principals,
            conditions)
    ]
[/#function]

[#function dynamodbManageTablesPermission tables="*" principals="" conditions={} ]
    [#return
        getDynamodbStatement(
            [
                "dynamodb:CreateTable",
                "dynamodb:UpdateTable",
                "dynamodb:DeleteTable"
            ],
            tables,
            [],
            [],
            principals,
            conditions)]
[/#function]

[#function dynamodbAllPermission tables="*" indexes=[] principals="" conditions={} ]
    [#return
        arrayIfTrue(
            [#-- Table permissions only if no indexes specified --]
            dynamodbReadPermission(
                tables,
                principals,
                conditions) +
            dynamodbWritePermission(
                tables,
                principals,
                conditions) +
            dynamodbDeletePermission(
                tables,
                principals,
                conditions),
            !indexes?has_content
        ) +
        dynamodbQueryPermission(
            tables,
            indexes,
            principals,
            conditions) +
        dynamodbScanPermission(
            tables,
            indexes,
            principals,
            conditions) ]
[/#function]

[#function dynamodbAdminPermission]
    [#return
        dynamodbAllPermission() +
        dynamodbManageTablesPermission() +
        getDynamodbStatement(
            [
                "dynamodb:DescribeLimits",
                "dynamodb:DescribeReservedCapacity",
                "dynamodb:DescribeReservedCapacityOfferings"
            ],
            "")]
    ]
[/#function]

[#function dynamoDbViewerPermission tables="*" indexes=[] principals="" conditions={} ]
    [#return
        arrayIfTrue(
            [#-- Table permissions only if no indexes specified --]
            dynamodbReadPermission(
                tables,
                principals,
                conditions),
            !indexes?has_content
        ) +
        dynamodbQueryPermission(
            tables,
            indexes,
            principals,
            conditions) +
        dynamodbScanPermission(
            tables,
            indexes,
            principals,
            conditions)
    ]
[/#function]


[#function dynamodbStreamRead tables="*" stream="*" principals="" conditions={} ]
    [#return
        getDynamodbStatement(
            [
                "dynamodb:DescribeStream",
                "dynamodb:GetRecords",
                "dynamodb:GetShardIterator",
                "dynamodb:ListStreams"
            ],
            tables,
            stream,
            [],
            principals,
            conditions
        )
    ]
[/#function]
