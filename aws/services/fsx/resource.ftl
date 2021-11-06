[#ftl]

[#assign FSX_FILESYSTEM_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        DNS_ATTRIBUTE_TYPE : {
            "Attribute" : "DNSName"
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_FSX_FILESYSTEM_RESOURCE_TYPE
    mappings=FSX_FILESYSTEM_OUTPUT_MAPPINGS
/]

[#-- Utitliy Functions --]
[#function getAmazonFSXMaintenanceWindow dayofWeek timeofDay timeZone="UTC" ]

    [#local dayList=["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]]
    [#local workDate = convertDayOfWeek2DateTime(dayofWeek, timeofDay, timeZone) ]
    [#local dow = dayList?seq_index_of(showDateTime(workDate, "EEE", "UTC"))+1]
    [#local retval = showDateTime(workDate, "${dow}:HH:mm", "UTC") ]
    [#return retval ]

[/#function]

[#function getAmazonFSXBackupWindow dayofWeek timeofDay timeZone="UTC" ]

    [#-- Always 1 hour before maintenance window --]
    [#local workDate = convertDayOfWeek2DateTime(dayofWeek, timeofDay, timeZone) ]
    [#local workDate = addDateTime(workDate, "hh", -1) ]

    [#local retval = showDateTime(workDate, "HH:mm", "UTC") ]
    [#return retval ]

[/#function]


[#function getFSXWindowsConfiguration
                directoryId
                throughputCapacity
                aliases
                maintenanceWindow
                backupRetentionDays
                multiAz
                subnets
                logDestinationId=""
                copyTagstoBackups=true ]
    [#return
        {
            "ActiveDirectoryId": directoryId,
            "ThroughputCapacity": throughputCapacity,

            "WeeklyMaintenanceStartTime": getAmazonFSXMaintenanceWindow(
                                                maintenanceWindow.DayOfTheWeek,
                                                maintenanceWindow.TimeOfDay,
                                                maintenanceWindow.TimeZone
                                            ),
            "DailyAutomaticBackupStartTime": getAmazonFSXBackupWindow(
                                                maintenanceWindow.DayOfTheWeek,
                                                maintenanceWindow.TimeOfDay,
                                                maintenanceWindow.TimeZone
                                            ),
            "AutomaticBackupRetentionDays": backupRetentionDays,
            "CopyTagsToBackups": copyTagstoBackups
        } +
        multiAz?then(
            {
                "DeploymentType" : "MULTI_AZ_1",
                "PreferredSubnetId": subnets[0]
            },
            {
                "DeploymentType" : "SINGLE_AZ_2"
            }
        ) +
        attributeIfContent(
           "Aliases",
           aliases
        ) +
        attributeIfContent(
            "AuditLogConfiguration",
            logDestinationId,
            {
                "AuditLogDestination" : getArn(logDestinationId),
                "FileAccessAuditLogLevel" : "SUCCESS_AND_FAILURE",
                "FileShareAccessAuditLogLevel" : "SUCCESS_AND_FAILURE"
            }
        )
    ]
[/#function]


[#-- Resource Macros --]
[#macro createFSXFileSystem id
        fsType
        subnets
        securityGroupIds
        encrypted
        kmsKeyId
        storageCapacity
        windowsConfiguration={}
        tags={}
        dependencies=[]]

    [#local fileSystemType = ""]

    [#switch fsType?lower_case ]
        [#case "smb" ]
        [#case "windows"]
            [#local fileSystemType = "WINDOWS"]
            [#break]

        [#default]
            [@fatal
                message="Unsupported FSX FileSystem Type"
                context={
                    "id" : id,
                    "FileSystemType" : fsType
                }
            /]
    [/#switch]

    [@cfResource
        id=id
        type="AWS::FSx::FileSystem"
        properties=
            {
                "FileSystemType" : fileSystemType,
                "Tags" : tags,
                "SubnetIds": subnets,
                "SecurityGroupIds" : getReferences(securityGroupIds)
            } +
            attributeIfContent(
                "WindowsConfiguration",
                windowsConfiguration
            ) +
            (storageCapacity>0)?then(
                {
                    "StorageCapacity" : storageCapacity
                },
                {}
            ) +
            encrypted?then(
                {
                    "KmsKeyId" : getReference(kmsKeyId, ARN_ATTRIBUTE_TYPE)
                },
                {}
            )
        outputs=FSX_FILESYSTEM_OUTPUT_MAPPINGS
    /]
[/#macro]
