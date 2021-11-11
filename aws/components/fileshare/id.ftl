[#ftl]
[@addResourceGroupInformation
    type=FILESHARE_COMPONENT_TYPE
    attributes=[
        {
            "Names" : "IAMRequired",
            "Description" : "Require IAM Access to EFS",
            "Types" : BOOLEAN_TYPE,
            "Default" : false
        },
        {
            "Names" : "ThroughputCapacity",
            "Description" : "The throughput capacity in  megabytes/second for fileshares",
            "Types" : NUMBER_TYPE,
            "Default" : 512
        }
    ]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_ELASTIC_FILE_SYSTEM_SERVICE,
            AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE,
            AWS_FSX_SERVICE
        ]
/]
