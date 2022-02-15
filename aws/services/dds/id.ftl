[#ftl]

[#-- Resources --]
[#assign AWS_DDS_RESOURCE_TYPE = "dds" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_DOCUMENT_DATABASE_SERVICE
    resource=AWS_DDS_RESOURCE_TYPE
/]
[#assign AWS_DDS_SUBNET_GROUP_RESOURCE_TYPE = "ddsSubnetGroup" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_DOCUMENT_DATABASE_SERVICE
    resource=AWS_DDS_SUBNET_GROUP_RESOURCE_TYPE
/]

[#assign AWS_DDS_PARAMETER_GROUP_RESOURCE_TYPE = "ddsParameterGroup" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_DOCUMENT_DATABASE_SERVICE
    resource=AWS_DDS_PARAMETER_GROUP_RESOURCE_TYPE
/]
[#assign AWS_DDS_OPTION_GROUP_RESOURCE_TYPE = "ddsOptionGroup" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_DOCUMENT_DATABASE_SERVICE
    resource=AWS_DDS_OPTION_GROUP_RESOURCE_TYPE
/]
[#assign AWS_DDS_SNAPSHOT_RESOURCE_TYPE = "ddsSnapShot" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_DOCUMENT_DATABASE_SERVICE
    resource=AWS_DDS_SNAPSHOT_RESOURCE_TYPE
/]

[#assign AWS_DDS_CLUSTER_RESOURCE_TYPE = "ddsCluster" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_DOCUMENT_DATABASE_SERVICE
    resource=AWS_DDS_CLUSTER_RESOURCE_TYPE
/]
[#assign AWS_DDS_CLUSTER_PARAMETER_GROUP_RESOURCE_TYPE = "ddsClusterParameterGroup" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_DOCUMENT_DATABASE_SERVICE
    resource=AWS_DDS_CLUSTER_PARAMETER_GROUP_RESOURCE_TYPE
/]

[#function formatDependentDDSSnapshotId resourceId extensions... ]
    [#return formatDependentResourceId(
                "snapshot",
                resourceId,
                extensions)]
[/#function]

[#function formatDependentDDSManualSnapshotId resourceId extensions... ]
    [#return formatDependentResourceId(
                "manualsnapshot",
                resourceId,
                extensions)]
[/#function]
