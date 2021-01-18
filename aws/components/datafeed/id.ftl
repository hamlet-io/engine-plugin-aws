[#ftl]
[@addResourceGroupInformation
    type=DATAFEED_COMPONENT_TYPE
    attributes=[
        {
            "Names" : "WAFLogFeed",
            "Description" : "Feed is intended for use with WAF. Enforces a strict naming convention required by the provider.",
            "Types" : BOOLEAN_TYPE,
            "Default" : false
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
