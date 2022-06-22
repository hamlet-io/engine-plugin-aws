[#ftl]

[#assign AWS_ECR_REPOSITORY_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        URL_ATTRIBUTE_TYPE: {
            "Attribute" : "RepositoryUri"
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_ECR_REPOSITORY_RESOURCE_TYPE
    mappings=AWS_ECR_REPOSITORY_OUTPUT_MAPPINGS
/]

[#macro createECRRepository
        id
        scanOnPush
        encryptionEnabled
        encryptionKeyId=""
        encryptionType=""
        name=""
        mutableTags=true
        tags=[]
        dependencies=[] ]

    [#local encryptionConfig = {}]
    [#if encryptionEnabled ]
        [#switch encryptionType ]
            [#case "AES256"]
                [#local encryptionType = mergeObjects(
                    encryptionConfig,
                    {
                        "EncryptionType" : encryptionType
                    }
                )]
                [#break]
            [#case "KMS"]
                [#if ! encryptionKeyId?has_content ]
                    [@fatal
                        message="encryptionKeyId required for ECR KMS encryption"
                        detail={
                            "RepositoryId": id,
                            "EncryptionType" : encryptionType
                        }
                    /]
                [/#if]
                [#local encryptionType = mergeObjects(
                    encryptionConfig,
                    {
                        "EncryptionType" : encryptionType,
                        "KmsKey" : getReference(encryptionKeyId)
                    }
                )]
                [#break]

            [#default]
                [@fatal
                    message="invalid encryption type ECR KMS encryption"
                    detail={
                        "RepositoryId": id,
                        "EncryptionType" : encryptionType
                    }
                /]
        [/#switch]
    [/#if]

    [@cfResource
        id=id
        type="AWS::ECR::Repository"
        properties={
            "ImageTagMutability" : mutableTags?then("MUTABLE", "IMMUTABLE")
        } +
        attributeIfContent(
            "RepositoryName",
            name
        ) +
        attributeIfTrue(
            "EncryptionConfiguration",
            encryptionEnabled,
            encryptionConfig
        ) +
        attributeIfTrue(
            "ImageScanningConfiguration",
            scanOnPush,
            {
                "ScanOnPush" : scanOnPush
            }
        )
        tags=tags
        outputs=AWS_ECR_REPOSITORY_OUTPUT_MAPPINGS
    /]
[/#macro]
