[#ftl]
[#macro aws_globaldb_cf_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract subsets=["template" ] /]
[/#macro]

[#macro aws_globaldb_cf_setup_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]
    [#local resources = occurrence.State.Resources]

    [#local tableId = resources["table"].Id ]
    [#local tableName = resources["table"].Name ]
    [#local tableKey = resources["table"].Key ]
    [#local tableSortKey = resources["table"].SortKey!"" ]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "Encryption" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]

    [#local kmsKeyId = baselineComponentIds["Encryption"]]

    [#local dynamoTableKeys = getDynamoDbTableKey(tableKey , "hash")]
    [#local dynamoTableKeyAttributes = getDynamoDbTableAttribute( tableKey, STRING_TYPE)]

    [#if (solution.SecondaryKey!"")?has_content ]
        [#local dynamoTableKeys += getDynamoDbTableKey(tableSortKey, "range" )]
        [#local dynamoTableKeyAttributes += getDynamoDbTableAttribute(tableSortKey, STRING_TYPE)]
    [/#if]


    [#if deploymentSubsetRequired(GLOBALDB_COMPONENT_TYPE, true) ]
        [@createDynamoDbTable
            id=tableId
            name=tableName
            backupEnabled=solution.Table.Backup.Enabled
            billingMode=solution.Table.Billing
            writeCapacity=solution.Table.Capacity.Write
            readCapacity=solution.Table.Capacity.Read
            attributes=dynamoTableKeyAttributes
            encrypted=solution.Table.Encrypted
            ttlKey=solution.TTLKey
            kmsKeyId=kmsKeyId
            keys=dynamoTableKeys
        /]
    [/#if]
[/#macro]
