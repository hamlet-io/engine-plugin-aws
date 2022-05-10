[#ftl]
[#macro aws_globaldb_cf_deployment_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract subsets=["template" ] /]
[/#macro]

[#macro aws_globaldb_cf_deployment_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]
    [#local resources = occurrence.State.Resources]

    [#local tableId = resources["table"].Id ]
    [#local tableName = resources["table"].Name ]
    [#local tableKey = resources["table"].Key ]
    [#local tableSortKey = resources["table"].SortKey!"" ]

    [#local billingMode = solution.Table.Billing ]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "Encryption" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]

    [#local kmsKeyId = baselineComponentIds["Encryption"]]

    [#-- attribute type overrides --]
    [#local attributeTypes = solution.KeyTypes!{} ]

    [#local attributes = {} ]

    [#-- Configure the primary key --]
    [#local dynamoTableKeys = getDynamoDbTableKey(tableKey , "hash")]
    [#local attributes += { tableKey : (attributeTypes[tableKey].Type)!STRING_TYPE } ]

    [#-- Configure the secondary key --]
    [#if tableSortKey?has_content ]
        [#local dynamoTableKeys += getDynamoDbTableKey(tableSortKey, "range" )]
        [#local attributes += { tableSortKey : (attributeTypes[tableSortKey].Type)!STRING_TYPE } ]
    [/#if]

    [#-- Global Secondary Indexes --]
    [#local globalSecondaryIndexes = [] ]
    [#list solution.SecondaryIndexes!{} as key,value]
        [#local globalSecondaryIndexes +=
            getGlobalSecondaryIndex(
                value.Name,
                billingMode,
                value.Keys,
                value.KeyTypes,
                value.Capacity.Write,
                value.Capacity.Read
            ) ]
        [#-- pick up any key attribute types as well --]
        [#list value.Keys as key]
            [#local attributes += { key : (attributeTypes[key].Type)!STRING_TYPE } ]
        [/#list]
    [/#list]

    [#-- Format the attributes --]
    [#local dynamoTableKeyAttributes = [] ]
    [#list attributes as key, value]
        [#local dynamoTableKeyAttributes += getDynamoDbTableAttribute(key, value)]
    [/#list]

    [#-- setup stream for changes made to table --]
    [#local streamViewType = ""]
    [#switch solution.ChangeStream.ChangeView ]
        [#case "KeysOnly" ]
            [#local streamViewType="KEYS_ONLY"]
            [#break]

        [#case "NewItem" ]
            [#local streamViewType="NEW_IMAGE"]
            [#break]

        [#case "OldItem"]
            [#local streamViewType="OLD_IMAGE"]
            [#break]

        [#case "NewAndOldItem"]
            [#local streamViewType="NEW_AND_OLD_IMAGES"]
            [#break]
    [/#switch]

    [#if deploymentSubsetRequired(GLOBALDB_COMPONENT_TYPE, true) ]

        [#list (solution.Alerts?values)?filter(x -> x.Enabled) as alert ]

            [#local monitoredResources = getCWMonitoredResources(core.Id, resources, alert.Resource)]
            [#list monitoredResources as name,monitoredResource ]

                [@debug message="Monitored resource" context=monitoredResource enabled=false /]
                [#local resourceDimensions = getCWMetricDimensions(alert, monitoredResource, resources) ]

                [#switch alert.Comparison ]
                    [#case "Threshold" ]
                        [@createAlarm
                            id=formatDependentAlarmId(monitoredResource.Id, alert.Id )
                            severity=alert.Severity
                            resourceName=core.FullName
                            alertName=alert.Name
                            actions=getCWAlertActions(occurrence, solution.Profiles.Alert, alert.Severity )
                            metric=getCWMetricName(alert.Metric, monitoredResource.Type, core.ShortFullName)
                            namespace=getCWResourceMetricNamespace(monitoredResource.Type, alert.Namespace)
                            description=alert.Description!alert.Name
                            threshold=alert.Threshold
                            statistic=alert.Statistic
                            evaluationPeriods=alert.Periods
                            period=alert.Time
                            operator=alert.Operator
                            reportOK=alert.ReportOk
                            unit=alert.Unit
                            missingData=alert.MissingData
                            dimensions=resourceDimensions
                        /]
                    [#break]
                [/#switch]
            [/#list]
        [/#list]

        [@createDynamoDbTable
            id=tableId
            name=tableName
            backupEnabled=solution.Table.Backup.Enabled
            billingMode=billingMode
            writeCapacity=solution.Table.Capacity.Write
            readCapacity=solution.Table.Capacity.Read
            attributes=dynamoTableKeyAttributes
            encrypted=solution.Table.Encrypted
            ttlKey=solution.TTLKey
            kmsKeyId=kmsKeyId
            keys=dynamoTableKeys
            globalSecondaryIndexes=globalSecondaryIndexes
            streamEnabled=solution.ChangeStream.Enabled
            streamViewType=streamViewType
        /]
    [/#if]
[/#macro]
