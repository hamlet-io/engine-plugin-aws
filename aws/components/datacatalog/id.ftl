[#ftl]

[@addResourceGroupInformation
    type=DATACATALOG_COMPONENT_TYPE
    attributes=[]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_GLUE_SERVICE
        ]
/]

[@addResourceGroupInformation
    type=DATACATALOG_TABLE_COMPONENT_TYPE
    attributes=[]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_GLUE_SERVICE,
            AWS_IDENTITY_SERVICE
        ]
/]
