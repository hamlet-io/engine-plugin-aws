[#ftl]
[@addResourceGroupInformation
    type=EFS_COMPONENT_TYPE
    attributes=[
        {
            "Names" : "Type",
            "Types" : STRING_TYPE,
            "Values" : [ "NFS", "FSX-WIN", "FSX-LUSTRE" ],
            "Default" : "NFS"
        },
        {
            "Names": "StorageCapacity",
            "Types": NUMBER_TYPE
        },
        {
            "Names" : "MaintenanceWindow",
            "AttributeSet" : MAINTENANCEWINDOW_ATTRIBUTESET_TYPE
        },
        {
            "Names" : "IAMRequired",
            "Description" : "Require IAM Access to EFS",
            "Types" : BOOLEAN_TYPE,
            "Default" : false
        }
    ]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_ELASTIC_FILE_SYSTEM_SERVICE,
            AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
        ]
/]
