[#ftl]

[@addResourceGroupInformation
    type=SECRETSTORE_COMPONENT_TYPE
    attributes=[
        {
            "Names": "Engine",
            "Types" : STRING_TYPE,
            "Values" : [ "secretsmanager" ],
            "Default" : "aws:secretsmanager"
        }
    ]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_SECRETS_MANAGER_SERVICE
        ]
/]
