[#ftl]

[#-- Resources --]
[#assign HAMLET_IMAGE_RESOURCE_TYPE = "image"]

[#macro aws_image_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local imageId = formatResourceId(HAMLET_IMAGE_RESOURCE_TYPE, core.Id)]
    [#local imageName = occurrence.Core.RawFullName ]

    [#local registryEndpoint = getRegistryEndPoint(solution.Format, occurrence)]
    [#local registryPrefix = getRegistryPrefix(solution.Format, occurrence)]

    [#local reference = getExistingReference(imageId)]

    [#local imageFileName = ""]
    [#local imageRegistryType = ""]
    [#local imageRegistry = ""]

    [#local resources = {
        "image" : {
            "Id" : imageId,
            "Name" : imageName,
            "Type" : HAMLET_IMAGE_RESOURCE_TYPE
        }
    }]

    [#switch solution.Format]
        [#case "scripts"]
        [#case "spa"]
        [#case "dataset"]
        [#case "lambda"]
        [#case "contentnode"]
        [#case "pipeline"]
        [#case "openapi"]

            [#local imageFileName = "${solution.Format}.zip"]
            [#local imageRegistryType = "s3"]
            [#break]

        [#case "lambda_jar" ]
            [#local imageFileName = "${solution.Format}.jar"]
            [#local imageRegistryType = "s3"]
            [#break]

        [#case "docker"]
            [#local imageRegistryType = "docker"]
            [#break]
    [/#switch]


    [#switch imageRegistryType]
        [#case "s3"]

            [#local imageRegistry = formatRelativePath(
                "s3://",
                registryEndpoint,
                registryPrefix,
                (getActiveLayer(PRODUCT_LAYER_TYPE).Name)!getActiveLayer(TENANT_LAYER_TYPE).Name,
                imageName
            )]
            [#local imageLocation = formatRelativePath(
                    imageRegistry,
                    reference,
                    imageFileName
                )]

            [#local resources = mergeObjects(
                resources,
                {
                    "image" : {
                        "Location" : imageLocation,
                        "Registry" : imageRegistry,
                        "ImageFileName": imageFileName,
                        "RegistryType" : imageRegistryType
                    },
                    "registry" : {
                        "Id": formatId(formatAccountS3Id("registry"), occurrence.Core.Id),
                        "Type": AWS_S3_RESOURCE_TYPE,
                        "Deployed" : getRegistryBucket()?has_content
                    }
                }
            )]
            [#break]

        [#case "docker"]
            [#local repositoryName = formatRelativePath(
                (getActiveLayer(PRODUCT_LAYER_TYPE).Name)!getActiveLayer(TENANT_LAYER_TYPE).Name,
                imageName
            )]

            [#local imageLocation = formatRelativePath(
                    registryEndpoint,
                    (getActiveLayer(PRODUCT_LAYER_TYPE).Name)!getActiveLayer(TENANT_LAYER_TYPE).Name,
                    "${imageName}:${reference}"
                )]
            [#local imageRegistry = formatRelativePath(
                    registryEndpoint,
                    repositoryName
                )]

            [#local resources = mergeObjects(
                resources,
                {
                    "image" : {
                        "Location" : imageLocation,
                        "Registry" : imageRegistry,
                        "ImageFileName": imageFileName,
                        "RegistryType" : imageRegistryType
                    },
                    "repository" : {
                        "Id": formatResourceId(AWS_ECR_REPOSITORY_RESOURCE_TYPE, occurrence.Core.Id),
                        "Name": repositoryName,
                        "Type": AWS_ECR_REPOSITORY_RESOURCE_TYPE
                    }
                }
            )]

            [#break]
    [/#switch]

    [#assign componentState =
        {
            "Resources" : resources,
            "Attributes" : {
                "REFERENCE": reference,
                "TAG" : getExistingReference(imageId, NAME_ATTRIBUTE_TYPE),
                "LOCATION": imageLocation
            }
        }
    ]
[/#macro]
