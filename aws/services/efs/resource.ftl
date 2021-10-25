[#ftl]

[#assign EFS_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[#assign EFS_MOUNT_TARGET_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[#assign EFS_ACCESS_POINT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "Attribute" : "Arn"
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_EFS_RESOURCE_TYPE
    mappings=EFS_OUTPUT_MAPPINGS
/]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_EFS_MOUNT_TARGET_RESOURCE_TYPE
    mappings=EFS_MOUNT_TARGET_MAPPINGS
/]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_EFS_ACCESS_POINT_RESOURCE_TYPE
    mappings=EFS_ACCESS_POINT_MAPPINGS
/]

[#function getAmazonEfsMaintenanceWindow dayofWeek timeofDay timeZone="UTC" ]
    [#local dayList=["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]]
    [#local workDate = convertDayOfWeek2DateTime(dayofWeek, timeofDay, timeZone) ]
    [#local dow = dayList?seq_index_of(showDateTime(workDate, "EEE", "UTC"))+1]
    [#local retval = showDateTime(workDate, "${dow}:HH:mm", "UTC") ]
    [#return retval ]
[/#function]

[#function getAmazonEfsBackupWindow dayofWeek timeofDay timeZone="UTC" ]
    [#-- Always 1 hour before maintenance window --]
    [#local workDate = convertDayOfWeek2DateTime(dayofWeek, timeofDay, timeZone) ]
    [#local workDate = addDateTime(workDate, "hh", -1) ]

    [#local retval = showDateTime(workDate, "HH:mm", "UTC") ]
    [#return retval ]
[/#function]

[#macro createEFS id tags encrypted kmsKeyId iamRequired=true type="NFS" fsx_config={} resourcePolicyStatements=[]  ]
    [#switch type]
        [#case "NFS"]
        [#case "NFS-MULTIAZ"]
            [@cfResource
                id=id
                type="AWS::EFS::FileSystem"
                properties=
                    {
                        "PerformanceMode" : "generalPurpose",
                        "FileSystemTags" : tags
                    } +
                    encrypted?then(
                        {
                            "Encrypted" : true,
                            "KmsKeyId" : getReference(kmsKeyId, ARN_ATTRIBUTE_TYPE)
                        },
                        {}
                    ) +
                    attributeIfTrue(
                        "FileSystemPolicy",
                        iamRequired,
                        getPolicyDocumentContent(resourcePolicyStatements)
                    )
                outputs=EFS_OUTPUT_MAPPINGS
            /]
        [#break]
        [#case "FSX-WIN"]
        [#case "FSX-WIN-MULTIAZ"]
            [#local winConfig = {
                    "ActiveDirectoryId": fsx_config.directoryId,
                    "ThroughputCapacity": 8,
                    "Aliases": fsx_config.aliases,
                    "WeeklyMaintenanceStartTime": getAmazonEfsMaintenanceWindow(fsx_config.maintenanceWindow.DayOfTheWeek, fsx_config.maintenanceWindow.TimeOfDay, fsx_config.maintenanceWindow.TimeZone),
                    "DailyAutomaticBackupStartTime": getAmazonEfsBackupWindow(fsx_config.maintenanceWindow.DayOfTheWeek, fsx_config.maintenanceWindow.TimeOfDay, fsx_config.maintenanceWindow.TimeZone),
                    "AutomaticBackupRetentionDays": 30,
                    "CopyTagsToBackups": false,
                    "DeploymentType": (type?contains("-MULTIAZ"))?then("MULTI_AZ_1","SINGLE_AZ_2")
                } + (type?contains("-MULTIAZ"))?then({"PreferredSubnetId": fsx_config.subnets[0]},{})
            ]
            [@cfResource
                id=id
                type="AWS::FSx::FileSystem"
                properties=
                    {
                        "FileSystemType" : "WINDOWS",
                        "Tags" : tags,
                        "SubnetIds": fsx_config.subnets,
                        "WindowsConfiguration" : winConfig
                    } +
                    (fsx_config.storageCapacity>0)?then(
                        {
                           "StorageCapacity" : fsx_config.storageCapacity
                        },
                        {}
                    ) +
                    encrypted?then(
                        {
                           "KmsKeyId" : getReference(kmsKeyId, ARN_ATTRIBUTE_TYPE)
                        },
                        {}
                    )
                outputs=EFS_OUTPUT_MAPPINGS
            /]
        [#break]
        [#case "FSX-LUSTRE"]
        [#case "FSX-LUSTRE-MULTIAZ"]
[#-- Doco says this FSx is for access by linux clients? Not sure if required. Included for completeness
            [@cfResource
                id=id
                type="AWS::FSx::FileSystem"
                properties=
                    {
                        "FileSystemType" : "LUSTRE",
                        "Tags" : tags,
                        "LustreConfiguration" : {
                            "AutoImportPolicy" : "NEW",               
                            "CopyTagsToBackups" : true,
                            "DeploymentType": "PERSISTENT_1",
                            "PerUnitStorageThroughput": 200,                    
                            "DataCompressionType": "LZ4",
                            "ImportPath": {
                                "Fn::Join": [
                                    "",
                                    [
                                        "s3://",
                                        {
                                            "Fn::ImportValue": "LustreCFNS3ImportBucketName"
                                        }
                                    ]
                                ]
                            },
                            "ExportPath": {
                                "Fn::Join": [
                                    "",
                                    [
                                        "s3://",
                                        {
                                            "Fn::ImportValue": "LustreCFNS3ExportPath"
                                        }
                                    ]
                                ]
                            },
                            "DailyAutomaticBackupStartTime": getAmazonEfsBackupWindow(fsx_config.maintenanceWindow.DayOfTheWeek, fsx_config.maintenanceWindow.TimeOfDay, fsx_config.maintenanceWindow.TimeZone),
                            "WeeklyMaintenanceStartTime": getAmazonEfsMaintenanceWindow(fsx_config.maintenanceWindow.DayOfTheWeek, fsx_config.maintenanceWindow.TimeOfDay, fsx_config.maintenanceWindow.TimeZone)
                        }
                    } +
                    encrypted?then(
                        {
                           "KmsKeyId" : getReference(kmsKeyId, ARN_ATTRIBUTE_TYPE)
                        },
                        {}
                    )
                outputs=EFS_OUTPUT_MAPPINGS
            /]
--]
        [#break]
    [/#switch]
[/#macro]

[#macro createEFSMountTarget id efsId subnet securityGroups type="NFS" dependencies="" ]
    [#switch type]
        [#case "NFS"]
            [@cfResource
                id=id
                type="AWS::EFS::MountTarget"
                properties=
                    {
                        "SubnetId" : subnet?is_enumerable?then(
                                        subnet[0],
                                        subnet
                        ),
                        "FileSystemId" : getReference(efsId),
                        "SecurityGroups": getReferences(securityGroups)
                    }
                outputs=EFS_MOUNT_TARGET_MAPPINGS
                dependencies=dependencies
            /]
        [#break]
        [#case "FSX-WIN"]
            [#-- Not required for this type --]
        [#break]
        [#case "FSX-LUSTRE"]
            [#-- Not required for this type --]
        [#break]
    [/#switch]
[/#macro]

[#macro createEFSAccessPoint id efsId tags
        overidePermissions=false
        type="NFS" 
        chroot=false
        uid=""
        gid=""
        secondaryGids=""
        permissions=""
        rootPath=""
    ]

    [#switch type]
        [#case "NFS"]
            [@cfResource
                id=id
                type="AWS::EFS::AccessPoint"
                properties=
                    {
                        "FileSystemId" : getReference(efsId),
                        "AccessPointTags" : tags
                    } +
                    attributeIfTrue(
                        "PosixUser",
                        overidePermissions,
                        {
                            "Uid" : uid,
                            "Gid" : gid
                        } +
                        attributeIfContent(
                            "SecondaryGids",
                            secondaryGids
                        )
                    ) +
                    attributeIfTrue(
                        "RootDirectory",
                        chroot,
                        {
                            "CreationInfo" : {
                                "OwnerUid" : uid,
                                "OwnerGid" : gid,
                                "Permissions" : permissions
                            },
                            "Path" : rootPath?remove_ending("/")?ensure_starts_with("/")
                        }
                    )
                outputs=EFS_ACCESS_POINT_MAPPINGS
                dependencies=dependencies
            /]
        [#break]
        [#case "FSX-WIN"]

        [#break]
        [#case "FSX-LUSTRE"]

        [#break]
    [/#switch]
[/#macro]
