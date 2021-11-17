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
