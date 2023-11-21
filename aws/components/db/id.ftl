[#ftl]
[@addResourceGroupInformation
    type=DB_COMPONENT_TYPE
    attributes=[]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_IDENTITY_SERVICE,
            AWS_CLOUDWATCH_SERVICE,
            AWS_KEY_MANAGEMENT_SERVICE,
            AWS_RELATIONAL_DATABASE_SERVICE,
            AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE,
            AWS_AUTOSCALING_SERVICE
        ]
/]


[@addResourceGroupAttributeValues
    type=DB_COMPONENT_TYPE
    provider=AWS_PROVIDER
    extensions=[
        {
            "Names" : "Storage",
            "Description" : "Additional storage configuration options",
            "Children" : [
                {
                    "Names": "Type",
                    "Description": "The type of storage to use for the database",
                    "Types": STRING_TYPE,
                    "Values" : ["gp2", "gp3", "io1", "standard"],
                    "Default": "gp2"
                },
                {
                    "Names": "Throughput",
                    "Description": "Specifiy the throughput you want for gp-3 volumes",
                    "Types" : NUMBER_TYPE,
                    "Default" : -1
                },
                {
                    "Names" : "Iops",
                    "Description" : "Specify the IOPS you want for types that support it",
                    "Types" : NUMBER_TYPE,
                    "Default": -1
                }
            ]
        }
    ]
/]
