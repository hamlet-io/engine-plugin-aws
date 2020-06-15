[#ftl]

[#-- Resources --]
[#assign AWS_SSM_DOCUMENT_RESOURCE_TYPE = "ssmDocument"]
[#assign AWS_SSM_MAINTENANCE_WINDOW_RESOURCE_TYPE = "ssmMaintenanceWindow" ]
[#assign AWS_SSM_MAINTENANCE_WINDOW_TARGET_RESOURCE_TYPE = "ssmWindowTarget" ]
[#assign AWS_SSM_MAINTENANCE_WINDOW_TASK_RESOURCE_TYPE = "ssmWindowTask" ]


[#-- Account level Session Manager Resources which are used by other components --]
[#function formatAccountSSMSessionManagerDocumentId ]
    [#return formatAccountResourceId(AWS_SSM_DOCUMENT_RESOURCE_TYPE, "console")]
[/#function]

[#function formatAccountSSMSessionManagerLogBucketId ]
    [#return formatAccountS3Id("console")]
[/#function]

[#function formatAccountSSMSessionManagerLogGroupId ]
    [#return migrateToResourceId(
        formatAccountResourceId(AWS_CLOUDWATCH_LOG_GROUP_RESOURCE_TYPE, "console"),
        [
            formatLogGroupId( "console" )
        ]
    )]
[/#function]
