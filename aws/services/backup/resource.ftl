[#ftl]

[#assign AWS_BACKUP_VAULT_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        NAME_ATTRIBUTE_TYPE : {
            "Attribute" : "BackupVaultName"
        },
        ARN_ATTRIBUTE_TYPE : {
            "Attribute" : "BackupVaultArn"
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_BACKUP_VAULT_RESOURCE_TYPE
    mappings=AWS_BACKUP_VAULT_OUTPUT_MAPPINGS
/]

[#macro createBackupVault id name accessPolicy={} encryptionKeyId="" notifications=[] lockConfiguration={} tags={} dependencies=""]
    [@cfResource
        id=id
        type="AWS::Backup::BackupVault"
        properties=
            {
                "BackupVaultName" : name
            } +
            attributeIfContent(
                "AccessPolicy",
                accessPolicy
            ) +
            attributeIfContent(
                "EncryptionKeyArn",
                encryptionKeyId,
                getArn(encryptionKeyId)
            ) +
            [#-- At present it looks like only one topic is supported as notifications is an object --]
            attributeIfTrue(
                "Notifications",
                notifications?has_content,
                notifications[0]
            ) +
            attributeIfContent(
                "LockConfiguration",
                lockConfiguration
            ) +
            attributeIfContent(
                "BackupVaultTags",
                tags
            )
        outputs=AWS_BACKUP_VAULT_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]

[#function addBackupNotification notifications arn events=[] ]
    [#return
        notifications +
        [
            {
                "SNSTopicArn" : arn,
                "BackupVaultEvents" : events
            }
        ]
    ]
[/#function]

[#function getBackupLockConfiguration minRetentionDays maxRetentionDays=0 changeableForDays=0 ]
    [#return
        {
            "MinRetentionDays" : minRetentionDays
        } +
        attributeIfTrue(
            "MaxRetentionDays",
            maxRetentionDays > 0,
            maxRetentionDays
        ) +
        attributeIfTrue(
            "ChangeableForDays",
            changeableForDays > 0
            changeableForDays
        )
    ]
[/#function]

[#assign AWS_BACKUP_PLAN_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "Attribute" : "BackupPlanArn"
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_BACKUP_PLAN_RESOURCE_TYPE
    mappings=AWS_BACKUP_PLAN_OUTPUT_MAPPINGS
/]

[#macro createBackupPlan id name rules=[] tags={} dependencies=""]
    [@cfResource
        id=id
        type="AWS::Backup::BackupPlan"
        properties=
            {
                "BackupPlan" : {
                    "BackupPlanName" : name,
                    "BackupPlanRule" : rules
                }
            } +
            attributeIfContent(
                "BackupPlanTags",
                tags
            )
        outputs=AWS_BACKUP_PLAN_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]

[#function addBackupRule rules name vaultId schedule="" lifecycle={} startWindow=0 finishWindow=0 pointInTime=false copyActions=[] tags={} ]
    [#return
        rules +
        [
            {
                "RuleName" : name,
                "TargetBackupVault" : getReference(vaultId),
                "EnableContinuousBackup" : pointInTime
            } +
            attributeIfContent(
                "ScheduleExpression",
                schedule
            ) +
            attributeIfContent(
                "Lifecycle",
                lifecycle
            ) +
            attributeIfTrue(
                "StartWindowMinutes",
                startWindow > 0,
                startWindow
            ) +
            attributeIfTrue(
                "CompletionWindowMinutes",
                finishWindow > 0,
                finishWindow
            ) +
            attributeIfContent(
                "CopyActions",
                copyActions
            ) +
            attributeIfContent(
                "RecoveryPointTags",
                tags
            )
        ]
    ]
[/#function]

[#function getBackupLifecycle offline=0 expiration=0 ]
    [#return
        attributeIfTrue(
            "MoveToColdStorageAfterDays",
            offline > 0,
            offline
        ) +
        attributeIfTrue(
            "DeleteAfterDays",
            expiration > 0,
            expiration
        )
    ]
[/#function]

[#function addBackupCopyAction actions vaultId lifecycle={} ]
    [#return
        actions +
        [
            {
            "DestinationBackupVaultArn" : getArn(vaultId)
            } +
            attributeIfContent(
                "Lifecycle",
                lifecycle
            )
        ]
    ]
[/#function]

[#assign AWS_BACKUP_SELECTION_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_BACKUP_SELECTION_RESOURCE_TYPE
    mappings=AWS_BACKUP_SELECTION_OUTPUT_MAPPINGS
/]

[#macro createBackupSelection id name planId roleId tags=[] resources=[] conditions={} exclusions=[] dependencies=""]

    [#-- Treat everything as a potential target by default (likely limited by conditions) --]
    [#local requiredResources = [ "*" ] ]

    [#-- If explicit targets have been provided, use those --]
    [#if tags?has_content || resources?has_content]
        [#local requiredResources = [] ]
        [#list resources as resource]
            [#local requiredResources += [ getArn(resource) ] ]
        [/#list]
    [/#if]


    [#local requiredExclusions = [] ]
    [#list exclusions as exclusion]
        [#local requiredExclusions += [ getArn(exclusion) ] ]
    [/#list]

    [@cfResource
        id=id
        type="AWS::Backup::BackupSelection"
        properties=
            {
                "BackupPlanId" : getReference(planId),
                "BackupSelection" : {
                    "SelectionName" : name,
                    "IamRoleArn" : getReference(roleId, ARN_ATTRIBUTE_TYPE)
                } +
                attributeIfContent(
                    "Conditions",
                    conditions
                ) +
                attributeIfContent(
                    "ListOfTags",
                    tags
                ) +
                attributeIfContent(
                    "Resources",
                    requiredResources
                ) +
                attributeIfContent(
                    "NotResources",
                    requiredExclusions
                )
            }
        outputs=AWS_BACKUP_SELECTION_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]

[#function addBackupSelectionCondition conditions key value type="StringEquals" ]
    [#return
        combineEntities(
            conditions,
            {
                type : [
                    {
                        "ConditionKey" : key,
                        "ConditionValue" : value
                    }
                ]
            },
            APPEND_COMBINE_BEHAVIOUR
        )
    ]
[/#function]

[#function addBackupSelectionTag tags key value type="StringEquals" ]
    [#return
        tags +
        [
            {
                "ConditionKey" : key,
                "ConditionValue" : value,
                "ConditionType" : type
            }
        ]
    ]
[/#function]
