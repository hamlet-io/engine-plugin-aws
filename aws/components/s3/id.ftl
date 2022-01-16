[#ftl]
[@addResourceGroupInformation
    type=S3_COMPONENT_TYPE
    attributes=[]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_SIMPLE_STORAGE_SERVICE,
            AWS_SIMPLE_EMAIL_SERVICE,
            AWS_SIMPLE_QUEUEING_SERVICE,
            AWS_SIMPLE_NOTIFICATION_SERVICE,
            AWS_LAMBDA_SERVICE,
            AWS_IDENTITY_SERVICE
        ]
/]


[@addResourceGroupAttributeValues
    type=S3_COMPONENT_TYPE
    provider=AWS_PROVIDER
    extensions=[
        {
            "Names" : "Notifications",
            "SubObjects" : true,
            "AttributeSet" : AWS_S3_NOTIFICATION_ATTRIBUTESET_TYPE
        },
        {
            "Names" : "Encryption",
            "Children" : [
                {
                    "Names" : [ "shared:EncryptionSource", "EncryptionSource" ],
                    "Types" : STRING_TYPE,
                    "Description" : "The encryption service to use - LocalService = S3, EncryptionService = native encryption service (kms)",
                    "Values" : [ "EncryptionService", "LocalService" ],
                    "Default" : "EncryptionService"
                }
            ]
        }
    ]
/]
