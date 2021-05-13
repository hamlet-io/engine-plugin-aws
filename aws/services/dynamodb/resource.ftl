[#ftl]

[#assign DYNAMODB_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "Attribute" : "Arn"
        },
        EVENTSTREAM_ATTRIBUTE_TYPE : {
            "Attribute" : "StreamArn"
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_DYNAMODB_TABLE_RESOURCE_TYPE
    mappings=DYNAMODB_OUTPUT_MAPPINGS
/]

[@addCWMetricAttributes
    resourceType=AWS_DYNAMODB_TABLE_RESOURCE_TYPE
    namespace="AWS/DynamoDB"
    dimensions={
        "TableName" : {
            "Output" : {
                "Attribute" : REFERENCE_ATTRIBUTE_TYPE
            }
        }
    }
/]

[#function getDynamoDbAttributeType type ]
    [#switch type?upper_case ]
        [#case STRING_TYPE?upper_case ]
        [#case "S" ]
            [#return "S" ]
            [#break]

        [#case NUMBER_TYPE?upper_case ]
        [#case "N"]
            [#return "N" ]
            [#break]

        [#case "BINARY" ]
        [#case "B" ]
            [#return  "B" ]
            [#break]

        [#default]
            [#return "" ]
            [@fatal
                message="Invalid Attribute type"
                context={ "Name" : name, "Type" : type }
            /]
    [/#switch]
[/#function]


[#function getDynamoDbTableAttribute name type ]
    [#return
        [
            {
                "AttributeName" : name,
                "AttributeType" : getDynamoDbAttributeType(type)
            }
        ]
    ]
[/#function]

[#function getDynamoDbTableKey name type ]
    [#local type = type?upper_case ]
    [#switch type ]
        [#case "HASH" ]
        [#case "RANGE" ]
            [#break]

        [#default]
            [@fatal
                message="Invalid Key type"
                context={ "Name" : name, "Type" : type }
            /]
    [/#switch]

    [#return
        [
            {
                "AttributeName" : name,
                "KeyType" : type
            }
        ]
    ]
[/#function]

[#function getDynamoDbTableItem name value type=STRING_TYPE ]
    [#return
        {
            name : {
                getDynamoDbAttributeType(type) : value
            }
        }
    ]
[/#function]

[#function getProvisionedThroughput writeCapacity readCapacity]
    [#return
        valueIfTrue(
            {
                "ReadCapacityUnits" : readCapacity,
                "WriteCapacityUnits" : writeCapacity
            },
            (writeCapacity != 0) && (readCapacity != 0)
        )
    ]
[/#function]

[#function getIndexProjection type keys=[] ]
    [#return
        {
            "ProjectionType" : type?upper_case
        } +
        attributeIfContent("NonKeyAttributes", keys)
    ]
[/#function]

[#function getGlobalSecondaryIndex name billingMode keys keyTypes=[]  writeCapacity=0 readCapacity=0 projectionType="all"]
    [#local keySchema = [] ]
    [#list keys as key]
        [#-- type default is hash, then range --]
        [#local keySchema +=
            getDynamoDbTableKey( key, keyTypes[key?index]!(valueIfTrue("hash",key?index == 0, "hash")) ) ]
    [/#list]

    [#local provisionedThroughput = {}]
    [#if billingMode?lower_case == "provisioned" ]
        [#local provisionedThroughput = getProvisionedThroughput(writeCapacity, readCapacity) ]
    [/#if]

    [#return
        [
            {
                "IndexName" : name,
                "KeySchema" : keySchema,
                "Projection" : getIndexProjection(projectionType)
            } +
            attributeIfContent("ProvisionedThroughput", provisionedThroughput)
        ]
    ]
[/#function]

[#macro createDynamoDbTable id
        backupEnabled
        billingMode
        attributes
        keys
        encrypted
        name=""
        ttlKey=""
        kmsKeyId=""
        name=""
        streamEnabled=false
        streamViewType=""
        writeCapacity=1
        readCapacity=1
        globalSecondaryIndexes=[]
]

    [#switch billingMode?lower_case ]
        [#case "provisioned" ]
            [#local billingMode = "PROVISIONED" ]
            [#break]
        [#case "per-request" ]
            [#local billingMode = "PAY_PER_REQUEST" ]
            [#break]
        [#default]
    [/#switch]

    [@cfResource
        id=id
        type="AWS::DynamoDB::Table"
        properties=
            {
                "AttributeDefinitions" : asArray(attributes),
                "BillingMode" : billingMode,
                "KeySchema" : asArray(keys),
                "Tags" : getCfTemplateCoreTags(name)
            } +
            attributeIfContent(
                "TableName",
                name
            ) +
            attributeIfTrue(
                "PointInTimeRecoverySpecification",
                backupEnabled,
                {
                    "PointInTimeRecoveryEnabled" : true
                }
            ) +
            attributeIfTrue(
                "ProvisionedThroughput",
                billingMode == "PROVISIONED",
                {
                    "ReadCapacityUnits" : readCapacity,
                    "WriteCapacityUnits" : writeCapacity
                }
            ) +
            attributeIfTrue(
                "StreamSpecification",
                streamEnabled,
                {
                    "StreamViewType" : streamViewType
                }
            ) +
            attributeIfTrue(
                "SSESpecification",
                encrypted,
                {
                    "KMSMasterKeyId" : getReference(kmsKeyId, ARN_ATTRIBUTE_TYPE),
                    "SSEEnabled" : true,
                    "SSEType" : "KMS"
                }
            ) +
            attributeIfContent(
                "TimeToLiveSpecification",
                ttlKey,
                {
                "AttributeName" : ttlKey,
                "Enabled" : true
                }
            ) +
            attributeIfContent(
                "GlobalSecondaryIndexes",
                globalSecondaryIndexes
            )
        outputs=DYNAMODB_OUTPUT_MAPPINGS +
                    attributeIfTrue(
                        EVENTSTREAM_ATTRIBUTE_TYPE,
                        !streamEnabled,
                        {
                            "Value" : "not-available"
                        }
                    )
    /]
[/#macro]
