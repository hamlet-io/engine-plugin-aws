[#ftl]

[#assign RDS_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        DNS_ATTRIBUTE_TYPE : {
            "Attribute" : "Endpoint.Address"
        },
        PORT_ATTRIBUTE_TYPE : {
            "Attribute" : "Endpoint.Port"
        },
        REGION_ATTRIBUTE_TYPE : {
            "Value" : { "Ref" : "AWS::Region" }
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_RDS_RESOURCE_TYPE
    mappings=RDS_OUTPUT_MAPPINGS
/]

[#assign RDS_CLUSTER_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        DNS_ATTRIBUTE_TYPE : {
            "Attribute" : "Endpoint.Address"
        },
        PORT_ATTRIBUTE_TYPE : {
            "Attribute" : "Endpoint.Port"
        },
        "read" + DNS_ATTRIBUTE_TYPE : {
            "Attribute" : "ReadEndpoint.Address"
        }
    }

]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_RDS_CLUSTER_RESOURCE_TYPE
    mappings=RDS_CLUSTER_OUTPUT_MAPPINGS
/]

[@addCWMetricAttributes
    resourceType=AWS_RDS_RESOURCE_TYPE
    namespace="AWS/RDS"
    dimensions={
        "DBInstanceIdentifier" : {
            "Output" : {
                "Attribute" : REFERENCE_ATTRIBUTE_TYPE
            }
        }
    }
/]

[@addCWMetricAttributes
    resourceType=AWS_RDS_CLUSTER_RESOURCE_TYPE
    namespace="AWS/RDS"
    dimensions={
        "DBClusterIdentifier" : {
            "Output" : {
                "Attribute" : REFERENCE_ATTRIBUTE_TYPE
            }
        }
    }
/]

[#function getAmazonRdsMaintenanceWindow dayofWeek timeofDay timeZone="UTC" offsetHrs=0 ]
    [#local startTime = convertDayOfWeek2DateTime(dayofWeek, timeofDay, timeZone) ]

    [#local startTime = addDateTime(startTime, "hh", offsetHrs) ]
    [#local endTime = addDateTime(startTime, "mm", 30) ]
    [#local retval = showDateTime(startTime, "EEE:HH:mm", "UTC")+"-"+showDateTime(endTime, "EEE:HH:mm", "UTC") ]

    [#return retval ]
[/#function]

[#macro createRDSInstance id name
    engine
    processor
    zoneId
    subnetGroupId
    parameterGroupId
    optionGroupId
    securityGroupId
    enhancedMonitoring
    enhancedMonitoringInterval
    performanceInsights
    performanceInsightsRetention
    tags
    caCertificate
    engineVersion=""
    clusterMember=false
    clusterId=""
    clusterPromotionTier=""
    multiAZ=false
    encrypted=false
    kmsKeyId=""
    masterUsername=""
    masterPassword=""
    databaseName=""
    port=""
    retentionPeriod=""
    size=""
    snapshotArn=""
    dependencies=""
    outputId=""
    allowMajorVersionUpgrade=true
    autoMinorVersionUpgrade=true
    deleteAutomatedBackups=true
    enhancedMonitoringRoleId=""
    deletionPolicy="Snapshot"
    updateReplacePolicy="Snapshot"
    maintenanceWindow=""
]
    [@cfResource
    id=id
    type="AWS::RDS::DBInstance"
    deletionPolicy=deletionPolicy
    updateReplacePolicy=updateReplacePolicy
    properties=
        {
            "Engine": engine,
            "DBInstanceClass" : processor,
            "AutoMinorVersionUpgrade": autoMinorVersionUpgrade,
            "AllowMajorVersionUpgrade" : allowMajorVersionUpgrade,
            "DeleteAutomatedBackups" : deleteAutomatedBackups,
            "DBSubnetGroupName": getReference(subnetGroupId),
            "DBParameterGroupName": getReference(parameterGroupId),
            "OptionGroupName": getReference(optionGroupId),
            "CACertificateIdentifier" : caCertificate
        } +
        attributeIfContent(
            "PreferredMaintenanceWindow",
            maintenanceWindow
        ) +
        valueIfTrue(
            {
                "AllocatedStorage": size?is_string?then(
                                        size,
                                        size?c?string
                                    ),
                "StorageType" : "gp2",
                "BackupRetentionPeriod" : retentionPeriod,
                "DBInstanceIdentifier": name,
                "VPCSecurityGroups": asArray( getReference(securityGroupId)),
                "Port" : port?c?string,
                "EngineVersion": engineVersion
            },
            ( !clusterMember ),
            {
                "DBClusterIdentifier" : getReference(clusterId),
                "PromotionTier" : clusterPromotionTier
            }

        ) +
        valueIfTrue(
            {
                "MultiAZ": true
            },
            ( multiAZ && !clusterMember ),
            {
                "AvailabilityZone" : getCFAWSAzReference(zoneId)
            }
        ) +
        valueIfTrue(
            {
                "StorageEncrypted" : true,
                "KmsKeyId" : getArn(kmsKeyId)
            },
            ( (!(snapshotArn?has_content) && encrypted) && !clusterMember )
        ) +
        [#-- If restoring from a snapshot the database details will be provided by the snapshot --]
        valueIfTrue(
            valueIfTrue(
                {
                    "DBSnapshotIdentifier" : snapshotArn
                },
                snapshotArn?has_content,
                {
                    "DBName" : databaseName,
                    "MasterUsername": masterUsername,
                    "MasterUserPassword": masterPassword
                }
            ),
            !clusterMember
        ) +
        performanceInsights?then(
            {
                "EnablePerformanceInsights" : performanceInsights,
                "PerformanceInsightsRetentionPeriod" : performanceInsightsRetention,
                "PerformanceInsightsKMSKeyId" : getArn(kmsKeyId)
            },
            {}
        ) +
        enhancedMonitoring?then(
            {
                "MonitoringInterval" : enhancedMonitoringInterval,
                "MonitoringRoleArn" : getArn(enhancedMonitoringRoleId)
            },
            {}
        )
    tags=tags
    outputs=
        RDS_OUTPUT_MAPPINGS +
        attributeIfContent(
            DATABASENAME_ATTRIBUTE_TYPE,
            databaseName,
            {
                "Value" : databaseName
            }
        ) +
        attributeIfContent(
            LASTRESTORE_ATTRIBUTE_TYPE,
            snapshotArn,
            {
                "Value" : snapshotArn
            }
        )
    /]
[/#macro]

[#macro createRDSCluster id name
    engine
    engineVersion
    port
    encrypted
    kmsKeyId
    masterUsername
    masterPassword
    databaseName
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
]

    [@cfResource
        id=id
        type="AWS::RDS::DBCluster"
        deletionPolicy=deletionPolicy
        updateReplacePolicy=updateReplacePolicy
        properties=
            {
                "DBClusterIdentifier" : name,
                "DBClusterParameterGroupName" : parameterGroupId,
                "DBSubnetGroupName" : subnetGroupId,
                "Port" : port,
                "VpcSecurityGroupIds" : asArray(securityGroupId),
                "AvailabilityZones" : getCFAWSAzReferences(getZones()?map(x -> x.Id)),
                "Engine" : engine,
                "EngineVersion" : engineVersion,
                "BackupRetentionPeriod" : retentionPeriod
            } +
            attributeIfContent(
                "PreferredMaintenanceWindow",
                maintenanceWindow
            ) +
            (!(snapshotArn?has_content) && encrypted)?then(
                {
                    "StorageEncrypted" : true,
                    "KmsKeyId" : getArn(kmsKeyId)
                },
                {}
            ) +
            [#-- If restoring from a snapshot the database details will be provided by the snapshot --]
            (snapshotArn?has_content)?then(
                {
                    "SnapshotIdentifier" : snapshotArn
                },
                {
                    "DatabaseName" : databaseName,
                    "MasterUsername": masterUsername,
                    "MasterUserPassword": masterPassword
                }
            )
        tags=tags
        outputs=RDS_CLUSTER_OUTPUT_MAPPINGS +
        {
            DATABASENAME_ATTRIBUTE_TYPE : {
                "Value" : databaseName
            }
        } +
        attributeIfContent(
            LASTRESTORE_ATTRIBUTE_TYPE,
            snapshotArn,
            {
                "Value" : snapshotArn
            }
        )
    /]
[/#macro]
