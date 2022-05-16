[#ftl]
[@addResourceGroupInformation
    type=DATASTREAM_COMPONENT_TYPE
    attributes=[
        {
            "Names": "Capacity",
            "Description" : "Manages the capacity of the datastream available",
            "Children" : [
                {
                    "Names" : "Shards",
                    "Description" : "The number of shards that the data is dividied into for consumers to access",
                    "Types" : NUMBER_TYPE,
                    "Default" : 1
                },
                {
                    "Names": "ProvisiningMode",
                    "DescribeStream" : "How the service is provisioned and charged",
                    "Types": STRING_TYPE,
                    "Values" : [ "provisioned", "on-demand" ],
                    "Default" : "on-demand"
                }
            ]
        }
    ]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_CLOUDWATCH_SERVICE,
            AWS_IDENTITY_SERVICE,
            AWS_KINESIS_SERVICE
        ]
/]
