[#ftl]

[#assign AWS_GLUE_DATABASE_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_GLUE_DATABASE_RESOURCE_TYPE
    mappings=AWS_GLUE_DATABASE_OUTPUT_MAPPINGS
/]

[#assign AWS_GLUE_TABLE_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_GLUE_TABLE_RESOURCE_TYPE
    mappings=AWS_GLUE_TABLE_OUTPUT_MAPPINGS
/]

[#assign AWS_GLUE_CRAWLER_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_GLUE_CRAWLER_RESOURCE_TYPE
    mappings=AWS_GLUE_CRAWLER_OUTPUT_MAPPINGS
/]

[#assign AWS_GLUE_CONNECTION_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_GLUE_CONNECTION_RESOURCE_TYPE
    mappings=AWS_GLUE_CONNECTION_OUTPUT_MAPPINGS
/]

[#-- Glue - Database --]
[#macro createAWSGlueDatabase id name description="" locationUri="" parameters={} ]
    [@cfResource
        id=id
        type="AWS::Glue::Database"
        properties={
            "CatalogId": {
                "Ref" : "AWS::AccountId"
            },
            "DatabaseInput": {
                "Name": name
            } +
            attributeIfContent(
                "Parameters",
                parameters
            ) +
            attributeIfContent(
                "Description",
                description
            ) +
            attributeIfContent(
                "LocationUri",
                locationUri
            )
        }
        outputs=AWS_GLUE_DATABASE_OUTPUT_MAPPINGS
    /]
[/#macro]

[#-- Glue - Table --]
[#function getAWSGlueTableColumn name type="" comment="" ]
    [#return
        {
            "Name": name
        } +
        attributeIfContent(
            "Type",
            type
        ) +
        attributeIfContent(
            "Comment",
            comment
        )
    ]
[/#function]

[#function getAWSGlueTableStorageDescriptor
        bucketColumns=[]
        columns=[]
        compressed=false
        inputFormat=""
        location=""
        numberOfBuckets=0
        outputFormat=""
        parameters={}
        schemaReference={}
        serdeSerializationLibrary=""
        serdeName=""
        serdeParameters={}
        skewedInfo={}
        sortColumns=[]
        storedAsSubDirectories=false
    ]

    [#local serdeInfo = {} +
        attributeIfContent(
            "SerializationLibrary",
            serdeSerializationLibrary
        ) +
        attributeIfContent(
            "Name",
            serdeName
        ) +
        attributeIfContent(
            "Parameters",
            serdeParameters
        )
    ]

    [#return
        {} +
        attributeIfContent(
            "BucketColumns",
            bucketColumns
        ) +
        attributeIfContent(
            "Columns",
            columns
        ) +
        attributeIfTrue(
            "Compressed",
            compressed,
            compressed
        ) +
        attributeIfContent(
            "InputFormat",
            inputFormat
        ) +
        attributeIfContent(
            "Location",
            location
        ) +
        attributeIfTrue(
            "NumberOfBuckets",
            numberOfBuckets > 0,
            numberOfBuckets
        ) +
        attributeIfContent(
            "OutputFormat",
            outputFormat
        ) +
        attributeIfContent(
            "Parameters",
            parameters
        ) +
        attributeIfContent(
            "SchemaReference",
            schemaReference
        ) +
        attributeIfContent(
            "SkewedInfo",
            skewedInfo
        ) +
        attributeIfContent(
            "SortColumns",
            sortColumns
        ) +
        attributeIfTrue(
            "StoredAsSubDirectories",
            storedAsSubDirectories,
            storedAsSubDirectories
        ) +
        attributeIfContent(
            "SerdeInfo",
            serdeInfo
        )
    ]

[/#function]

[#macro createAWSGlueTable
        id
        name
        databaseId
        parameters={}
        partitionKeys=[]
        retention=0
        storageDescriptor={} ]

    [@cfResource
        id=id
        type="AWS::Glue::Table"
        properties={
            "CatalogId": {
                "Ref" : "AWS::AccountId"
            },
            "DatabaseName": getReference(databaseId),
            "TableInput": {
                "Name": name,
                "TableType": "EXTERNAL_TABLE",
                "PartitionKeys": partitionKeys
            } +
            attributeIfContent(
                "Parameters",
                parameters
            ) +
            attributeIfTrue(
                "Retention",
                retention > 0,
                retention
            ) +
            attributeIfContent(
                "StorageDescriptor",
                storageDescriptor
            )
        }
        outputs=AWS_GLUE_TABLE_OUTPUT_MAPPINGS
    /]
[/#macro]

[#-- Glue - Crawler --]
[#function getAWSGlueCrawlerConfiguration
        combineCompatibleSchemas=true
        tableLevel=0
        tableThreshold=0 ]

    [#local grouping = {} +
        atrributeIfTrue(
            "TableGroupingPolicy",
            combineCompatibleSchemas,
            "CombineCompatibleSchemas"
        ) +
        attributeIfTrue(
            "TableLevelConfiguration",
            (tableLevel > 0),
            tableLevel
        ) ]

    [#local result = { } +
        attributeIfContent(
            "Grouping",
            grouping
        ) +
        attributeIfTrue(
            "CrawlerOutput",
            (tableThreshold > 0),
            {
                "Tables": {
                    "tableThreshold" : tableThreshold
                }
            }
        )
    ]

    [#if result?has_content ]
        [#local result = mergeObjects(
            {
                "Version": 1.0
            },
            result
        )]
    [/#if]
    [#return result]
[/#function]

[#function getAWSGlueCrawlerTarget
        type
        glueConnectionId=""
        catalogDatabaseId=""
        catalogTableIds=[]
        dynmodbTableId=""
        jdbcExclusions=[]
        jdbcPath=""
        mongoPath=""
        s3EventDlqId=""
        s3EventQueueId=""
        s3Path=""
        s3SampleSize=0]

    [#local result = {}]

    [#switch type ]
        [#case "catalog" ]
            [#local result = {
                "DatabaseName" : getReference(catalogId),
                "Tables" : getReferences(catalogTableIds)
            }]
            [#break]

        [#case "dynamodb"]
            [#local result = {
                "Path": getReference(dynmoDbTableId)
            }]
            [#break]

        [#case "jdbc"]
            [#local result = {
                "ConnectionName": getReference(glueConnectionId)
            } +
            attributeIfContent(
                "Exclusions",
                jdbcExclusions
            ) +
            attributeIfContent(
                "Path",
                jdbcPath
            ) ]
            [#break]

        [#case "mongodb"]
            [#local result = {
                "ConnectionName": getReference(glueConnectionId)
            } +
            attributeIfContent(
                "Path",
                mongoPath
            ) ]
            [#break]

        [#case "s3"]
            [#local result = {
                "ConnectionName": getReference(glueConnectionId)
            } +
            attributeIfContent(
                "DlqEventQueueArn",
                getArn(s3EventDlqId)
            ) +
            attributeIfContent(
                "EventQueueArn",
                getArn(s3EventQueueId)
            ) +
            attributeIfContent(
                "Path",
                s3Path
            ) +
            attributeIfTrue(
                "SampleSize",
                s3SampleSize > 0,
                s3SampleSize
            )]
            [#break]

        [#default]
            [@fatal
                message="Invalid glue crawler target type"
                context={
                    "Id": id,
                    "Type": type
                }
            /]
    [/#switch]
    [#return result]
[/#function]

[#macro createAWSGlueCrawler
            id
            name
            roleId
            targets
            description=""
            classifiers=[]
            cnfiguration={}
            crawlerSecurityConfigurationId=""
            glueDatabaseId=""
            recrawlBehaviour=""
            scheduleExpression=""
            schemaChangeDeleteBehaviour=""
            schemaChangeUpdateBehaviour=""
            tablePrefix=""
            tags={} ]

    [#local recrawlBehavior = recrawlBehavior?upper_case ]
    [#switch recrawlBehaviour]
        [#case "CRAWL_EVERYTHING"]
        [#case "EVERYTHING"]
            [#local recrawlBehavior = "CRAWL_EVERYTHING" ]
            [#break]
        [#case "CRAWL_NEW_FOLDERS_ONLY"]
        [#case "NEWONLY"]
            [#local recrawlBehavior = "CRAWL_NEW_FOLDERS_ONLY" ]
            [#break]
        [#default]
            [@fatal
                message="Invalid glue cralwer recrawlBehavior"
                context={
                    "id": id,
                    "recrawlBehaviour": recrawlBehaviour
                }
            /]
    [/#switch]

    [#local schemaChangeDeleteBehaviour = schemaChangeDeleteBehaviour?upper_case]
    [#switch schemaChangeDeleteBehaviour]
        [#case "LOG"]
            [#break]

        [#case "DELETE_FROM_DATABASE"]
        [#case "DELETE"]
            [#local schemaChangeDeleteBehaviour = "DELETE_FROM_DATABASE"]
            [#break]

        [#case "DEPRECATE_IN_DATABASE"]
        [#case "DEPRECATE"]
            [#local schemaChangeDeleteBehaviour = "DEPRECATE_IN_DATABASE"]
            [#break]

        [#default]
            [@fatal
                message="Invalid glue cralwer schema change delete behaviour"
                context={
                    "id": id,
                    "schemaChangeDeleteBehaviour": schemaChangeDeleteBehaviour
                }
            /]
    [/#switch]

    [#local schemaChangeUpdateBehaviour = schemaChangeUpdateBehaviour?upper_case]
    [#switch schemaChangeUpdateBehaviour]
        [#case "LOG"]
            [#break]
        [#case "UPDATE_IN_DATABASE"]
        [#case "UPDATE"]
            [#local schemaChangeUpdateBehaviour = "UPDATE_IN_DATABASE"]
            [#break]

        [#default]
            [@fatal
                message="Invalid glue cralwer schema change update behaviour"
                context={
                    "id": id,
                    "schemaChangeUpdateBehaviour": schemaChangeUpdateBehaviour
                }
            /]
    [/#switch]

    [#local schemaChangePolicy = {} +
        attributeIfContent(
            "UpdateBehavior",
            schemaChangeUpdateBehaviour
        )+
        attributeIfContent(
            "DeleteBehavior",
            schemaChangeDeleteBehaviour
        )]

    [@cfResource
        id=id
        type="AWS::Glue::Crawler"
        properties={
            "Name": name,
            "Role": getArn(roleId),
            "Targets": targets
        } +
        attributeIfContent(
            "Description",
            description
        ) +
        attributeIfContent(
            "Classifiers",
            classifiers
        ) +
        attributeIfContent(
            "Configuration",
            cnfiguration
        ) +
        attributeIfContent(
            "CrawlerSecurityConfiguration",
            getReference(crawlerSecurityConfigurationId)
        ) +
        attributeIfContent(
            "DatabaseName",
            getReference(databaseId)
        ) +
        attributeIfContent(
            "RecrawlPolicy",
            recrawlBehaviour,
            {
                "RecrawlBehavior": recrawlBehavior
            }
        ) +
        attributeIfContent(
            "Schedule",
            scheduleExpression,
            {
                "ScheduleExpression": scheduleExpression
            }
        ) +
        attributeIfContent(
            "SchemaChangePolicy",
            schemaChangePolicy
        ) +
        attributeIfContent(
            "TablePrefix",
            tablePrefix
        )
        tags=tags
        outputs=AWS_GLUE_CRAWLER_OUTPUT_MAPPINGS
    /]
[/#macro]

[#-- Glue - Connection --]
[#macro createAWSGlueConnection
        id
        name
        description
        connectionType
        connectionProperties={}
        matchCriteria=[]
        subnetId=""
        availabilityZone=""
        securityGroupIds=[] ]

    [#local connectionType = connectionType?upper_case]
    [#switch connectionType ]
        [#case "JDBC"]
        [#case "KAFKA"]
        [#case "MONGODB"]
        [#case "NETWORK"]
            [#break]

        [#default]
            [@fatal
                message="Invalid glue connection type"
                context={
                    "Id": id,
                    "ConnectionType": connectionType
                }
            /]
    [/#switch]

    [@cfResource
        id=id
        type="AWS::Glue::Connection"
        properties={
            "CatalogId": {
                "Ref" : "AWS::AccountId"
            },
            "ConnectionInput": {
                "Name": name,
                "ConnectionType": connectionType
            } +
            attributeIfContent(
                "ConnectionProperties",
                connectionProperties
            ) +
            attributeIfContent(
                "Description",
                description
            ) +
            attributeIfContent(
                "MatchCriteria",
                matchCriteria
            ) +
            attributeIfContent(
                "PhysicalConnectionRequirements",
                subnetId,
                {
                    "SubnetId": subnetId,
                    "SecurityGroupIdList": getReferences(securityGroupIds),
                    "AvailabilityZone": availabilityZone
                }
            )
        }
        outputs=AWS_GLUE_CONNECTION_OUTPUT_MAPPINGS
    /]
[/#macro]
