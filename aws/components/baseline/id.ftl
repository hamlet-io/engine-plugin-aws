[#ftl]

[@addResourceGroupInformation
    type=BASELINE_COMPONENT_TYPE
    attributes=[]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_CLOUDFRONT_SERVICE,
            AWS_KEY_MANAGEMENT_SERVICE,
            AWS_SIMPLE_STORAGE_SERVICE,
            AWS_SIMPLE_NOTIFICATION_SERVICE,
            AWS_SIMPLE_QUEUEING_SERVICE,
            AWS_BASELINE_PSEUDO_SERVICE,
            AWS_IDENTITY_SERVICE
        ]
/]


[@addResourceGroupAttributeValues
    type=BASELINE_DATA_COMPONENT_TYPE
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
