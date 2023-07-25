[#ftl]

[#-- Resources --]
[#assign AWS_EFS_RESOURCE_TYPE = "efs" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_FILE_SYSTEM_SERVICE
    resource=AWS_EFS_RESOURCE_TYPE
/]

[#assign AWS_EFS_MOUNT_TARGET_RESOURCE_TYPE = "efsMountTarget" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_FILE_SYSTEM_SERVICE
    resource=AWS_EFS_MOUNT_TARGET_RESOURCE_TYPE
/]
[#assign AWS_EFS_ACCESS_POINT_RESOURCE_TYPE = "efsAccessPoint" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_FILE_SYSTEM_SERVICE
    resource=AWS_EFS_ACCESS_POINT_RESOURCE_TYPE
/]
