[#ftl]
[@addResourceGroupInformation
    type=MTA_COMPONENT_TYPE
    attributes=[]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_SIMPLE_EMAIL_SERVICE,
            AWS_IDENTITY_SERVICE
        ]
/]

[@addResourceGroupInformation
    type=MTA_RULE_COMPONENT_TYPE
    attributes=[
        {
            "Names" : "Prefix",
            "Description" : "Prefix when saving to an S3 bucket",
            "Types" : STRING_TYPE,
            "Default" : ""
        },
        {
            "Names" : "Encryption",
            "Description" : "Details of message encryption",
            "Types" : STRING_TYPE,
            "Children" : [
                {
                    "Names" : "Enabled",
                    "Types" : BOOLEAN_TYPE,
                    "Default" : false
                }
            ]
        }
    ]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_SIMPLE_EMAIL_SERVICE,
            AWS_IDENTITY_SERVICE
        ]
/]
