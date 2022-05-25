[#ftl]
[@addResourceGroupInformation
    type=DATAFEED_COMPONENT_TYPE
    attributes=[
        {
            "Names" : "WAFLogFeed",
            "Description" : "Feed is intended for use with WAF. Enforces a strict naming convention required by the provider.",
            "Types" : BOOLEAN_TYPE,
            "Default" : false
        },
        {
            "Names" : "Partitioning",
            "Description" : "Control configuration of dynamic partitioning",
            "Children" : [
                {
                    "Names" : "Enabled",
                    "Description" : "Partitioning can only be set at time of creation so default it to false to cover existing deployments",
                    "Types" : BOOLEAN_TYPE,
                    "Default" : false
                },
                {
                    "Names" : "Delimiter",
                    "Description" : "Control configuration of delimiter processor",
                    "Children" : [
                        {
                            "Names" : "Enabled",
                            "Description" : "Delimiter processor is added after any lambda processors",
                            "Types" : BOOLEAN_TYPE,
                            "Default" : false
                        },
                        {
                            "Names" : "Token",
                            "Description" : "String added to the end of every datafeed record",
                            "Types" : STRING_TYPE,
                            "Default" : r"\n"
                        }
                    ]
                }
            ]
        },
        {
            "Names" : "DataStreamSource",
            "Description" : "Use a data stream as the source of data for the feed",
            "Children" : [
                {
                    "Names" : "Enabled",
                    "Description": "Require the use of a data stream as the data source",
                    "Types" : BOOLEAN_TYPE,
                    "Default" : false
                },
                {
                    "Names" : "Link",
                    "Description" : "A link to the datastream to use as the source",
                    "AttributeSet": LINK_ATTRIBUTESET_TYPE
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
