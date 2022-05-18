[#ftl]

[@addResourceGroupInformation
    type=LOGSTORE_COMPONENT_TYPE
    attributes=[]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_CLOUDWATCH_SERVICE
        ]
/]

[@addResourceGroupAttributeValues
    type=LOGSTORE_COMPONENT_TYPE
    provider=AWS_PROVIDER
    extensions=[
        {
            "Names": "Engine",
            "Types" : STRING_TYPE,
            "Values" : [ "aws:cloudwatchlogs" ],
            "Default" : "aws:cloudwatchlogs"
        }
    ]
/]
