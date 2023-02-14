[#ftl]

[@addResourceGroupInformation
    type=IMAGE_COMPONENT_TYPE
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    attributes=[]
    services=[
        AWS_ELASTIC_CONTAINER_REGISTRY_SERVICE,
        AWS_IMAGE_SERVICE
    ]
/]


[@addResourceGroupAttributeValues
    type=IMAGE_COMPONENT_TYPE
    provider=AWS_PROVIDER
    extensions=[
        {
            "Names" : "Format:docker",
            "Children" : [
                {
                    "Names": "Encryption",
                    "Children" : [
                        {
                            "Names" : [ "EncryptionSource" ],
                            "Types" : STRING_TYPE,
                            "Description" : "The encryption service to use - LocalService = S3, EncryptionService = native encryption service (kms)",
                            "Values" : [ "EncryptionService", "LocalService" ],
                            "Default" : "EncryptionService"
                        }
                    ]
                }
            ]
        }
    ]
/]
