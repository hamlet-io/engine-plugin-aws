[#ftl]

[#assign DDS_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        DNS_ATTRIBUTE_TYPE : {
            "Attribute" : "Endpoint"
        },
        PORT_ATTRIBUTE_TYPE : {
            "Attribute" : "Port"
        },
        REGION_ATTRIBUTE_TYPE : {
            "Value" : { "Ref" : "AWS::Region" }
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_DDS_RESOURCE_TYPE
    mappings=DDS_OUTPUT_MAPPINGS
/]

[#assign DDS_CLUSTER_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        CLUSTER_ID_ATTRIBUTE_TYPE : {
            "Attribute" : "ClusterResourceId"
        },
        DNS_ATTRIBUTE_TYPE : {
            "Attribute" : "Endpoint"
        },
        PORT_ATTRIBUTE_TYPE : {
            "Attribute" : "Port"
        },
        "read" + DNS_ATTRIBUTE_TYPE : {
            "Attribute" : "ReadEndpoint"
        }
    }

]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_DDS_CLUSTER_RESOURCE_TYPE
    mappings=DDS_CLUSTER_OUTPUT_MAPPINGS
/]

[@addCWMetricAttributes
    resourceType=AWS_DDS_RESOURCE_TYPE
    namespace="AWS/DDS"
    dimensions={
        "DBInstanceIdentifier" : {
            "Output" : {
                "Attribute" : REFERENCE_ATTRIBUTE_TYPE
            }
        }
    }
/]

[@addCWMetricAttributes
    resourceType=AWS_DDS_CLUSTER_RESOURCE_TYPE
    namespace="AWS/DDS"
    dimensions={
        "DBClusterIdentifier" : {
            "Output" : {
                "Attribute" : REFERENCE_ATTRIBUTE_TYPE
            }
        }
    }
/]

[#function getAmazonDdsMaintenanceWindow dayofWeek timeofDay timeZone="UTC" offsetHrs=0 ]
    [#local startTime = convertDayOfWeek2DateTime(dayofWeek, timeofDay, timeZone) ]

    [#local startTime = addDateTime(startTime, "hh", offsetHrs) ]
    [#local endTime = addDateTime(startTime, "mm", 30) ]
    [#local retval = showDateTime(startTime, "EEE:HH:mm", "UTC")+"-"+showDateTime(endTime, "EEE:HH:mm", "UTC") ]

    [#return retval ]
[/#function]

[#function getAmazonDdsBackupWindow timeofDay timeZone="UTC" offsetHrs=0 ]
    [#-- Utiliose Monday as a dummy day to enable use of existing date functions --]
    [#local startTime = convertDayOfWeek2DateTime("Monday", timeofDay, timeZone) ]

    [#local startTime = addDateTime(startTime, "hh", offsetHrs) ]
    [#local endTime = addDateTime(startTime, "mm", 30) ]
    [#local retval = showDateTime(startTime, "HH:mm", "UTC")+"-"+showDateTime(endTime, "HH:mm", "UTC") ]

    [#return retval ]
[/#function]

[#macro createDDSInstance id name
    processor
    zoneId
    tags
    clusterId=""
    dependencies=""
    outputId=""
    autoMinorVersionUpgrade=true
    deletionPolicy="Snapshot"
    updateReplacePolicy="Snapshot"
    maintenanceWindow=""
]
    [@cfResource
    id=id
    type="AWS::DocDB::DBInstance"
    deletionPolicy=deletionPolicy
    updateReplacePolicy=updateReplacePolicy
    properties=
        {
            "DBInstanceClass" : processor,
            "AutoMinorVersionUpgrade": autoMinorVersionUpgrade,
            "AvailabilityZone" : getCFAWSAzReference(zoneId),
            "DBClusterIdentifier" : getReference(clusterId)
        } +
        attributeIfContent(
            "PreferredMaintenanceWindow",
            maintenanceWindow
        )
    tags=tags
    outputs=
        DDS_OUTPUT_MAPPINGS +
        attributeIfContent(
            CLUSTER_ID_ATTRIBUTE_TYPE,
            clusterId,
            {
                "Value" : clusterId
            }
        )
    /]
[/#macro]

[#macro createDDSCluster id name
    engineVersion
    port
    encrypted
    kmsKeyId
    masterUsername
    masterPassword
    retentionPeriod
    subnetGroupId
    parameterGroupId
    snapshotArn
    securityGroupId
    tags
    dependencies=""
    outputId=""
    deletionPolicy="Snapshot"
    updateReplacePolicy="Snapshot"
    maintenanceWindow=""
    backupWindow=""
]
    [#local zoneIds=[] ]
    [#list zones as zone ]
        [#local zoneIds += [ zone.Id ] ]
    [/#list]

    [@cfResource
        id=id
        type="AWS::DocDB::DBCluster"
        deletionPolicy=deletionPolicy
        updateReplacePolicy=updateReplacePolicy
        properties=
            {
                "DBClusterIdentifier" : name,
                "DBClusterParameterGroupName" : parameterGroupId,
                "DBSubnetGroupName" : subnetGroupId,
                "Port" : port,
                "VpcSecurityGroupIds" : asArray(securityGroupId),
                "AvailabilityZones" : getCFAWSAzReferences(zoneIds),
                "EngineVersion" : engineVersion,
                "BackupRetentionPeriod" : retentionPeriod
            } +
            attributeIfContent(
                "PreferredMaintenanceWindow",
                maintenanceWindow
            ) +
            attributeIfContent(
                "PreferredBackupWindow",
                backupWindow
            ) +
            (!(snapshotArn?has_content) && encrypted)?then(
                {
                    "StorageEncrypted" : true,
                    "KmsKeyId" : getReference(kmsKeyId, ARN_ATTRIBUTE_TYPE)
                },
                {}
            ) +
            [#-- If restoring from a snapshot the database details will be provided by the snapshot --]
            (snapshotArn?has_content)?then(
                {
                    "SnapshotIdentifier" : snapshotArn
                },
                {
                    "MasterUsername": masterUsername,
                    "MasterUserPassword": masterPassword
                }
            )
        tags=tags
        outputs=DDS_CLUSTER_OUTPUT_MAPPINGS +
        attributeIfContent(
            LASTRESTORE_ATTRIBUTE_TYPE,
            snapshotArn,
            {
                "Value" : snapshotArn
            }
        )
    /]
[/#macro]
