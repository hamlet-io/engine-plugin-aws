[#ftl]
[@addResourceGroupInformation
    type=USER_COMPONENT_TYPE
    attributes=[]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_APIGATEWAY_SERVICE,
            AWS_IDENTITY_SERVICE,
            AWS_SIMPLE_STORAGE_SERVICE,
            AWS_KEY_MANAGEMENT_SERVICE,
            AWS_TRANSFER_SERVICE
        ]
/]


[@addResourceGroupAttributeValues
    type=USER_COMPONENT_TYPE
    provider=AWS_PROVIDER
    extensions=[
        {
            "Names" : "PermissionsBoundaryPolicyArn",
            "Types": STRING_TYPE,
            "Description": "The Arn of a Permissions Boundary Policy Arn"
        }
    ]
/]
