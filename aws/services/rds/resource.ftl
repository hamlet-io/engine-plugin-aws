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

[#assign RDS_EVENT_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_RDS_EVENT_RESOURCE_TYPE
    mappings=RDS_EVENT_OUTPUT_MAPPINGS
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

[#assign DB_MASTER_PASSWORD_PARAMETER_TYPE = "DBMasterPassword"]

[#function getDbMasterPasswordRef dbId source password ]
    [#switch source ]
        [#case "cfnparam"]
            [#local passwordParamId = formatId(DB_MASTER_PASSWORD_PARAMETER_TYPE, dbId)]
            [@cfParameter
                id=passwordParamId
                type="String"
                default=password
                noEcho=true
            /]
            [#local masterPasswordRef = getReference(passwordParamId)]
            [#break]
        [#case "ssm"]
            [#local masterPasswordRef = password ]
            [#break]
    [/#switch]

    [#return masterPasswordRef!"HamletFatal: invalid DB Master password source ${source}"]
[/#function]

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
    cloudWatchLogExports=[]
    engineVersion=""
    clusterMember=false
    clusterId=""
    clusterPromotionTier=""
    multiAZ=false
    encrypted=false
    kmsKeyId=""
    masterUsername=""
    masterPassword=""
    masterPasswordSource=""
    databaseName=""
    port=""
    retentionPeriod=""
    storageType=""
    storageIops=0
    storageThroughput=0
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
    copyTagsToSnapshot=false
    deletionProtection=false
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
                    "StorageType" : storageType,
                    "BackupRetentionPeriod" : retentionPeriod,
                    "DBInstanceIdentifier": name,
                    "VPCSecurityGroups": asArray( getReference(securityGroupId)),
                    "Port" : port?c?string,
                    "EngineVersion": engineVersion,
                    "CopyTagsToSnapshot": copyTagsToSnapshot,
                    "DeletionProtection": deletionProtection
                } +
                valueIfTrue(
                    {
                        "Iops": storageIops
                    },
                    (["gp3", "io1"]?seq_contains(storageType) && storageIops > 0 )
                ) +
                valueIfTrue(
                    {
                        "StorageThroughput": storageThroughput
                    },
                    ( storageType == "gp3" && storageThroughput > 0 )
                ),
                ( !clusterMember ),
                {
                    "DBClusterIdentifier" : getReference(clusterId),
                    "PromotionTier" : clusterPromotionTier
                }

            ) +
            attributeIfContent(
                "EnableCloudwatchLogsExports",
                cloudWatchLogExports
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
                        "MasterUserPassword": getDbMasterPasswordRef(id, masterPasswordSource, masterPassword)
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
    masterPasswordSource
    databaseName
    retentionPeriod
    subnetGroupId
    parameterGroupId
    snapshotArn
    securityGroupId
    tags
    cloudWatchLogExports=[]
    dependencies=""
    outputId=""
    deletionPolicy="Snapshot"
    updateReplacePolicy="Snapshot"
    maintenanceWindow=""
    copyTagsToSnapshot=false
    deletionProtection=false
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
                "BackupRetentionPeriod" : retentionPeriod,
                "CopyTagsToSnapshot": copyTagsToSnapshot,
                "DeletionProtection": deletionProtection
            } +
            attributeIfContent(
                "EnableCloudwatchLogsExports",
                cloudWatchLogExports
            ) +
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
                    "MasterUserPassword": getDbMasterPasswordRef(id, masterPasswordSource, masterPassword)
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

[#macro createRDSEvent id
    rdsId
    linkArn
    linkRoles
    sourceType
]
    [@cfResource
        id=id
        type="AWS::RDS::EventSubscription"
        properties=
            {
                "Enabled" : true,
                "SnsTopicArn" : linkArn,
                "SourceIds" : [ getReference(rdsId) ],
                "SourceType" : sourceType
            } +
            attributeIfTrue(
                "EventCategories",
                !linkRoles?seq_contains("_all"),
                linkRoles
            )
        outputs=RDS_EVENT_OUTPUT_MAPPINGS
    /]
[/#macro]

[#assign RDS_PROXY_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "Attribute": "DBProxyArn"
        },
        DNS_ATTRIBUTE_TYPE : {
            "Attribute": "Endpoint"
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_RDS_PROXY_RESOURCE_TYPE
    mappings=RDS_PROXY_OUTPUT_MAPPINGS
/]


[#function getRDSProxyAuthFormat authScheme="" description="" secretId="" userName="" iamAuthState=""  ]
    [#if iamAuthState?has_content ]
        [#switch iamAuthState?upper_case ]
            [#case "ENABLED"]
            [#case "DISABLED"]
            [#case "REQUIRED"]
                [#break]
            [#default]
                [@fatal
                    message="Invlaid RDS Proxy Auth Format - IAMAuth"
                    context={
                        "Provided": iamAuthState,
                        "Possible" : [
                            "ENABLED",
                            "DISABLED",
                            "REQUIRED"
                        ]
                    }
                /]
        [/#switch]
    [/#if]

    [#if authScheme?has_content ]
        [#switch authScheme?upper_case ]
            [#case "SECRETS"]
                [#break]
            [#default]
                [@fatal
                    message="Invlaid RDS Proxy Auth Format - AuthScheme"
                    context={
                        "Provided": iamAuthState,
                        "Possible" : [
                            "ENABLED",
                            "DISABLED",
                            "REQUIRED"
                        ]
                    }
                /]
        [/#switch]
    [/#if]

    [#return {} +
        attributeIfContent(
            "AuthScheme",
            authScheme?upper_case
        ) +
        attributeIfContent(
            "Description",
            description
        ) +
        attributeIfContent(
            "IAMAuth",
            iamAuthState?upper_case
        ) +
        attributeIfContent(
            "SecretArn",
            getArn(secretId)
        ) +
        attributeIfContent(
            "UserName",
            userName
        )
    ]
[/#function]

[#macro createRDSProxy id name
        debugLogging
        engineFamily
        requireTLS
        roleId
        tags
        authFormats=[]
        idleClientTimeout=0
        vpcSecurityGroupIds=[]
        vpcSubnets=[]
        dependencies=[] ]

    [@cfResource
        id=id
        type="AWS::RDS::DBProxy"
        properties={
            "DBProxyName": name,
            "DebugLogging": debugLogging,
            "EngineFamily": engineFamily,
            "RequireTLS": requireTLS,
            "RoleArn": getArn(roleId)
        } +
        attributeIfContent(
            "Auth",
            asArray(authFormats)
        ) +
        attributeIfTrue(
            "IdleClientTimeout",
            idleClientTimeout > 0,
            idleClientTimeout
        ) +
        attributeIfContent(
            "VpcSecurityGroupIds",
            vpcSecurityGroupIds,
            getReferences(vpcSecurityGroupIds)
        ) +
        attributeIfContent(
            "VpcSubnetIds",
            vpcSubnets
        )
        tags=tags
        outputs=RDS_PROXY_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]

[#assign RDS_PROXY_ENDPOINT_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE: {
            "Attribute" : "DBProxyEndpointArn"
        },
        DNS_ATTRIBUTE_TYPE: {
            "Attribute" : "Endpoint"
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_RDS_PROXY_ENDPOINT_RESOURCE_TYPE
    mappings=RDS_PROXY_ENDPOINT_OUTPUT_MAPPINGS
/]

[#macro createRDSProxyEndpoint id name
        proxyId
        tags
        targetRole
        vpcSecurityGroupIds
        vpcSubnets
        dependencies=[] ]

    [#switch targetRole?upper_case ]
        [#case "READONLY"]
        [#case "READ_ONLY"]
            [#local targetRole = "READ_ONLY"]
            [#break]
        [#case "READWRITE"]
        [#case "READ_WRITE"]
            [#local targetRole = "READ_WRITE"]
            [#break]
    [/#switch]

    [@cfResource
        id=id
        type="AWS::RDS::DBProxyEndpoint"
        properties={
            "DBProxyEndpointName": name,
            "DBProxyName" : getReference(proxyId),
            "TargetRole" : targetRole,
            "VpcSecurityGroupIds" : getReferences(vpcSecurityGroupIds),
            "VpcSubnetIds": vpcSubnets
        }
        tags=tags
        outputs=RDS_PROXY_ENDPOINT_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]

[#assign RDS_PROXY_TARGET_GROUP_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_RDS_PROXY_TARGET_GROUP_RESOURCE_TYPE
    mappings=RDS_PROXY_TARGET_GROUP_OUTPUT_MAPPINGS
/]


[#function getRDSProxyTargetGroupConnectionPoolConfig
    connectionBorrowTimeout=0
    initQuery=""
    maxConnectionsPercent=0
    maxIdleConnectionsPercent=0
    sessionPinningFilters=[]
]

    [#return {} +
        attributeIfTrue(
            "ConnectionBorrowTimeout",
            connectionBorrowTimeout > 0,
            connectionBorrowTimeout
        ) +
        attributeIfContent(
            "InitQuery",
            initQuery
        ) +
        attributeIfTrue(
            "MaxConnectionsPercent",
            connectionBorrowTimeout > 0,
            connectionBorrowTimeout
        ) +
        attributeIfTrue(
            "MaxIdleConnectionsPercent",
            maxIdleConnectionsPercent > 0,
            maxIdleConnectionsPercent
        ) +
        attributeIfContent(
            "SessionPinningFilters",
            sessionPinningFilters
        )]
[/#function]

[#macro createRDSProxyTargetGroup id name
        proxyId
        connectionPoolConfiguration
        dbClusterIds=[]
        dbInstanceIds=[]
        dependencies=[]]

    [@cfResource
        id=id
        type="AWS::RDS::DBProxyTargetGroup"
        properties={
            "TargetGroupName" : name,
            "DBProxyName": getReference(proxyId)
        } +
        attributeIfContent(
            "DBClusterIdentifiers",
            dbClusterIds,
            getReferences(dbClusterIds)
        ) +
        attributeIfContent(
            "DBClusterIdentifiers",
            dbInstanceIds,
            getReferences(dbInstanceIds)
        ) +
        attributeIfContent(
            "ConnectionPoolConfigurationInfo"
            connectionPoolConfiguration
        )
        outputs=RDS_PROXY_TARGET_GROUP_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]
