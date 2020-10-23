[#ftl]

[#-- Resources --]
[#assign AWS_RDS_RESOURCE_TYPE = "rds" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_RELATIONAL_DATABASE_SERVICE
    resource=AWS_RDS_RESOURCE_TYPE
/]
[#assign AWS_RDS_SUBNET_GROUP_RESOURCE_TYPE = "rdsSubnetGroup" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_RELATIONAL_DATABASE_SERVICE
    resource=AWS_RDS_SUBNET_GROUP_RESOURCE_TYPE
/]

[#assign AWS_RDS_PARAMETER_GROUP_RESOURCE_TYPE = "rdsParameterGroup" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_RELATIONAL_DATABASE_SERVICE
    resource=AWS_RDS_PARAMETER_GROUP_RESOURCE_TYPE
/]
[#assign AWS_RDS_OPTION_GROUP_RESOURCE_TYPE = "rdsOptionGroup" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_RELATIONAL_DATABASE_SERVICE
    resource=AWS_RDS_OPTION_GROUP_RESOURCE_TYPE
/]
[#assign AWS_RDS_SNAPSHOT_RESOURCE_TYPE = "rdsSnapShot" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_RELATIONAL_DATABASE_SERVICE
    resource=AWS_RDS_SNAPSHOT_RESOURCE_TYPE
/]

[#assign AWS_RDS_CLUSTER_RESOURCE_TYPE = "rdsCluster" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_RELATIONAL_DATABASE_SERVICE
    resource=AWS_RDS_CLUSTER_RESOURCE_TYPE
/]
[#assign AWS_RDS_CLUSTER_PARAMETER_GROUP_RESOURCE_TYPE = "rdsClusterParameterGroup" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_RELATIONAL_DATABASE_SERVICE
    resource=AWS_RDS_CLUSTER_PARAMETER_GROUP_RESOURCE_TYPE
/]

[#function formatDependentRDSSnapshotId resourceId extensions... ]
    [#return formatDependentResourceId(
                "snapshot",
                resourceId,
                extensions)]
[/#function]

[#function formatDependentRDSManualSnapshotId resourceId extensions... ]
    [#return formatDependentResourceId(
                "manualsnapshot",
                resourceId,
                extensions)]
[/#function]
