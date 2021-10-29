[#ftl]

[@addResourceGroupInformation
    type=SECRETSTORE_COMPONENT_TYPE
    attributes=[]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_SECRETS_MANAGER_SERVICE
        ]
/]

[@addResourceGroupAttributeValues
    type=SECRETSTORE_COMPONENT_TYPE
    provider=AWS_PROVIDER
    extensions=[
        {
            "Names": "Engine",
            "Types" : STRING_TYPE,
            "Values" : [ "secretsmanager" ],
            "Default" : "aws:secretsmanager"
        }
    ]
/]

[@addResourceGroupInformation
    type=SECRETSTORE_SECRET_COMPONENT_TYPE
    attributes=[]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_SECRETS_MANAGER_SERVICE
        ]
/]
