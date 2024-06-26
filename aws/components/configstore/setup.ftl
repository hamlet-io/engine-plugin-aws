[#ftl]
[#macro aws_configstore_cf_deployment_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract subsets=["deploymentcontract", "template", "epilogue", "cli"] /]
[/#macro]

[#macro aws_configstore_cf_deployment_deploymentcontract occurrence ]
    [@addDefaultAWSDeploymentContract epilogue=true /]
[/#macro]

[#macro aws_configstore_cf_deployment occurrence_solution ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local parentCore = occurrence.Core]
    [#local parentSolution = occurrence.Configuration.Solution]
    [#local parentResources = occurrence.State.Resources]

    [#local tableId = parentResources["table"].Id ]
    [#local tableKey = parentResources["table"].Key ]
    [#local tableSortKey = parentResources["table"].SortKey!"" ]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "OpsData", "AppData", "Encryption" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local kmsKeyId = baselineComponentIds["Encryption"]]

    [#local operationsBucket = getExistingReference(baselineComponentIds["OpsData"]) ]
    [#local dataBucket = getExistingReference(baselineComponentIds["AppData"])]

    [#local itemInitCommand = "initItem"]
    [#local itemUpdateCommand = "updateItem" ]
    [#local tableCleanupCommand = "cleanupTable" ]

    [#local dynamoTableKeys = getDynamoDbTableKey(tableKey , "hash")]
    [#local dynamoTableKeyAttributes = getDynamoDbTableAttribute( tableKey, STRING_TYPE)]

    [#if parentSolution.SecondaryKey ]
        [#local dynamoTableKeys += getDynamoDbTableKey(tableSortKey, "range" )]
        [#local dynamoTableKeyAttributes += getDynamoDbTableAttribute(tableSortKey, STRING_TYPE)]
    [/#if]

    [#local runIdAttributeName = "runId" ]
    [#local runIdAttribute = getDynamoDbTableItem( ":run_id", getCLORunId())]

    [#-- Lookup table name once it has been deployed --]
    [#if deploymentSubsetRequired("epilogue", false)]
        [@addToDefaultBashScriptOutput
            content=[
                " case $\{STACK_OPERATION} in",
                "   create|update)",
                "       # Get cli config file",
                "       split_cli_file \"$\{CLI}\" \"$\{tmpdir}\" || return $?",
                "       # Get DynamoDb TableName",
                "       export tableName=$(get_cloudformation_stack_output" +
                "       \"" + region + "\" " +
                "       \"$\{STACK_NAME}\" " +
                "       \"" + tableId + "\" " +
                "       || return $?)",
                "       ;;",
                " esac"
            ]
        /]
    [/#if]

    [#-- Branch setup --]
    [#list (occurrence.Occurrences![])?filter(x -> x.Configuration.Solution.Enabled ) as subOccurrence]

        [#local core = subOccurrence.Core ]
        [#local solution = subOccurrence.Configuration.Solution ]
        [#local resources = subOccurrence.State.Resources ]

        [#local itemId = resources["item"].Id]
        [#local itemPrimaryKey = resources["item"].PrimaryKey ]
        [#local itemSecondaryKey = (resources["item"].SecondaryKey)!"" ]

        [#local initCliId = formatId( itemId, "init")]
        [#local updateCliId = formatId( itemId, "update" )]

        [#local contextLinks = getLinkTargets(subOccurrence)]

        [#local _context =
            {
                "Environment" : {},
                "Links" : contextLinks,
                "BaselineLinks" : baselineLinks,
                "DefaultEnvironment" : defaultEnvironment(subOccurrence, contextLinks, baselineLinks),
                "DefaultCoreVariables" : false,
                "DefaultEnvironmentVariables" : false,
                "DefaultLinkVariables" : true,
                "DefaultBaselineVariables" : false,
                "Branch" : formatName(itemPrimaryKey + itemSecondaryKey)
            }
        ]

        [#-- Add in extension specifics including override of defaults --]
        [#local _context = invokeExtensions( subOccurrence, _context, occurrence )]

        [#local finalEnvironment = getFinalEnvironment(subOccurrence, _context ) ]
        [#local _context += finalEnvironment ]

        [#local _context +=
            {
                "Environment" : {
                                    "configStore" : parentCore.Id
                                } +
                                (_context.Environment!{})

            }
        ]

        [#if deploymentSubsetRequired("cli", false) ]

            [#local branchItemKey = getDynamoDbTableItem( tableKey, itemPrimaryKey )]

            [#if parentSolution.SecondaryKey ]
                [#local branchItemKey = mergeObjects(branchItemKey, getDynamoDbTableItem( tableSortKey, itemSecondaryKey) ) ]
            [/#if]

            [#local branchUpdateAttribtueValues = runIdAttribute ]
            [#local branchUpdateExpression =
                [
                    runIdAttributeName + " = :run_id"
                ]
            ]

            [#list solution.States as id,state ]
                [#local branchUpdateAttribtueValues += getDynamoDbTableItem( ":" + state.Name, state.InitialValue )]
                [#local branchUpdateExpression += [ state.Name + " = if_not_exists(" + state.Name + ", :" + state.Name + ")" ]]
            [/#list]

            [#list _context.Environment as envKey, envValue ]
                [#if envValue?has_content ]
                    [#local branchUpdateAttribtueValues += getDynamoDbTableItem( ":" + envKey, envValue )]
                    [#local branchUpdateExpression += [ envKey + " = :" + envKey ]]
                [/#if]
            [/#list]

            [@addCliToDefaultJsonOutput
                id=updateCliId
                command=itemUpdateCommand
                content={
                    "Key" : branchItemKey
                } +
                attributeIfContent(
                    "UpdateExpression",
                    branchUpdateExpression,
                    "SET " + branchUpdateExpression?join(", ")
                ) +
                attributeIfContent(
                    "ExpressionAttributeValues",
                    branchUpdateAttribtueValues
                )
            /]
        [/#if]


        [#if deploymentSubsetRequired("epilogue", false)]
            [@addToDefaultBashScriptOutput
                content=[
                    " case $\{STACK_OPERATION} in",
                    "   create|update)",
                    "       # Manage Branch Attributes",
                    "       info \"Creating DynamoDB Item - Table: " + tableId + " - Primary Key: " + itemPrimaryKey + " - Secondary Key: " + itemSecondaryKey "\"",
                    "       upsert_dynamodb_item" +
                    "       \"" + region + "\" " +
                    "       \"$\{tableName}\" " +
                    "       \"$\{tmpdir}/cli-" + updateCliId + "-" + itemUpdateCommand + ".json\" " +
                    "       \"$\{STACK_NAME}\" " +
                    "       || return $?",
                    "       ;;",
                    " esac"
                ]
            /]
        [/#if]
    [/#list]

    [#-- cleanup old items --]
    [#if deploymentSubsetRequired("cli", false) ]
        [#local cleanupFilterExpression = "NOT " + runIdAttributeName + " = :run_id"  ]
        [#local cleanupExpressionAttributeValues = runIdAttribute ]

        [#local projectionExpression = [ "#" + tableKey]  ]
        [#local expressionAttributeNames = { "#" + tableKey : tableKey } ]

        [#if parentSolution.SecondaryKey ]
            [#local projectionExpression += [ "#" + tableSortKey ] ]
            [#local expressionAttributeNames += { "#" + tableSortKey : tableSortKey } ]
        [/#if]

        [@addCliToDefaultJsonOutput
            id=tableId
            command=tableCleanupCommand
            content={
                "FilterExpression" : cleanupFilterExpression,
                "ExpressionAttributeValues" : cleanupExpressionAttributeValues,
                "ProjectionExpression" : projectionExpression?join(", "),
                "ExpressionAttributeNames" : expressionAttributeNames
            }
        /]
    [/#if]

    [#if deploymentSubsetRequired("epilogue", false)]
        [@addToDefaultBashScriptOutput
            content=[
                " case $\{STACK_OPERATION} in",
                "   create|update)",
                "       # Clean up old branch items",
                "       info \"Cleaning up old items DynamoDB - Table: " + tableId + "\"",
                "       old_items=$(scan_dynamodb_table" +
                "       \"" + region + "\" " +
                "       \"$\{tableName}\" " +
                "       \"$\{tmpdir}/cli-" + tableId + "-" + tableCleanupCommand + ".json\" " +
                "       \"$\{STACK_NAME}\" " +
                "       || return $?)",
                "       delete_dynamodb_items" +
                "       \"" + region + "\" " +
                "       \"$\{tableName}\" " +
                "       \"$\{old_items}\" " +
                "       \"$\{STACK_NAME}\" " +
                "       || return $?",
                "       ;;",
                " esac"
                ]
        /]
    [/#if]

    [#if deploymentSubsetRequired(CONFIGSTORE_COMPONENT_TYPE, true) ]
        [@createDynamoDbTable
            id=tableId
            backupEnabled=parentSolution.Table.Backup.Enabled
            billingMode=parentSolution.Table.Billing
            writeCapacity=parentSolution.Table.Capacity.Write
            readCapacity=parentSolution.Table.Capacity.Read
            encrypted=parentSolution.Table.Encrypted
            kmsKeyId=kmsKeyId
            attributes=dynamoTableKeyAttributes
            keys=dynamoTableKeys
            tags=getOccurrenceTags(occurrence)
        /]
    [/#if]
[/#macro]
