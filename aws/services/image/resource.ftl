[#ftl]

[#function constructAWSImageResource occurrence imageFormat imageConfiguration={} id="default"]

    [#local imageId = formatResourceId(HAMLET_IMAGE_RESOURCE_TYPE, occurrence.Core.Id, id)]

    [#local imageConfiguration = imageConfiguration?has_content?then(
        imageConfiguration,
        (occurrence.Configuration.Solution.Image)!{}
    )]

    [#if ! imageConfiguration?has_content ]
        [@fatal
            message="Could not find image configuration for occurrence"
            detail={
                "Occurrence" : {
                    "Name": occurrence.Core.RawName,
                    "Type" : occurrence.Core.Type
                },
                "imageConfiguration" : imageConfiguration
            }
        /]
        [#return {}]
    [/#if]

    [#local resource = {
        "Id": imageId,
        "Type": HAMLET_IMAGE_RESOURCE_TYPE
    }]

    [#local referenceSource = ""]
    [#local imageName = formatName(occurrence.Core.RawFullName, id) ]

    [#-- Image Source Control --]
    [#switch (imageConfiguration.Source)!"none" ]
        [#case "link"]
            [#local imageLink = getLinkTarget(occurrence, imageConfiguration.Link, false )]
            [#local image = {}]
            [#if imageLink?has_content]
                [#local image = ((imageLink.State.Images)?values?filter(x -> x.Format == imageFormat)[0])!{} ]
                [#if !image?has_content ]
                    [@fatal
                        message="Link Image format doesn't match required image format"
                        context={
                            "Name": occurrence.Core.RawFullName,
                            "AvailableImages": imageLink.State.Images,
                            "RequiredImageFormat": imageFormat
                        }
                    /]
                [/#if]
            [/#if]

            [#return { id: mergeObjects(image, {"Source": imageConfiguration.Source})}]
            [#break]

        [#case "extension"]
        [#case "none"]
            [#return { id: mergeObjects(resource, { "Source" : imageConfiguration.Source})}]
            [#break]

        [#case "registry"]
        [#case "Local"]
            [#-- Get Image Reference details --]
            [#local reference = getExistingReference(imageId)]
            [#local tag = getExistingReference(imageId, TAG_ATTRIBUTE_TYPE)]

            [#if getOccurrenceBuildReference(occurrence, true)?has_content ]
                [#local reference = getOccurrenceBuildReference(occurrence) ]
                [#local tag = (occurrence.Configuration.Settings.Build.APP_REFERENCE.Value)!""]
                [#local imageName = getOccurrenceBuildUnit(occurrence)]
                [#local referenceSource = "setting"]
            [/#if]

            [#local resource = mergeObjects(
                resource,
                {
                    "Reference": reference,
                    "Tag": tag
                }
            )]
            [#break]

        [#case "ContainerRegistry"]
        [#case "containerregistry"]
            [#local tag = (imageConfiguration["Source:ContainerRegistry"]["Image"])?keep_after_last("/")?keep_after(":")]
            [#local reference = tag?has_content?then(tag, "latest")]
            [#local resource = mergeObjects(
                resource,
                {
                    "Reference": reference,
                    "Tag": reference
                }
            )]
            [#break]
    [/#switch]

    [#local resource = mergeObjects(
        resource,
        {
            "Name": imageName,
            "Format" : imageFormat,
            "Source" : imageConfiguration.Source
        }
    )]

    [#-- Set the image details based on the format --]
    [#local imageFileName = ""]
    [#local imageRegistryType = ""]
    [#switch imageFormat]
        [#case "scripts"]
        [#case "spa"]
        [#case "lambda"]
        [#case "contentnode"]
        [#case "pipeline"]
        [#case "openapi"]

            [#local imageFileName = "${imageFormat}.zip"]
            [#local imageRegistryType = "s3"]
            [#break]

        [#case "dataset"]
            [#local imageRegistryType = "s3"]
            [#break]

        [#case "lambda_jar" ]
            [#local imageFileName = "${imageFormat}.jar"]
            [#local imageRegistryType = "s3"]
            [#break]

        [#case "docker"]
            [#local imageRegistryType = "docker"]
            [#break]

        [#case "rdssnapshot"]
            [#local imageRegistryType = "rdssnapshot"]
            [#break]
    [/#switch]

    [#local resource = mergeObjects(
        resource,
        {
            "RegistryType" : imageRegistryType,
            "ImageFileName" : imageFileName
        }
    )]

    [#-- Determine the full path to the registry image --]
    [#local registryEndpoint = ""]

    [#local registryPath = ""]
    [#local imageLocation = ""]
    [#local sourceLocation = ""]

    [#switch imageRegistryType]
        [#case "s3"]

            [#local registryEndpoint = getRegistryBucket(occurrence.State.ResourceGroups.default.Placement.Region)]

            [#switch referenceSource ]
                [#case "setting"]

                    [#local registryPath = formatRelativePath(
                        "s3://",
                        registryEndpoint,
                        imageFormat,
                        getOccurrenceBuildProduct(occurrence, getActiveLayer(PRODUCT_LAYER_TYPE).Name),
                        getOccurrenceBuildScopeExtension(occurrence),
                        resource.Name
                    )]
                    [#local imageLocation = formatRelativePath(
                            registryPath,
                            resource.Reference,
                            imageFileName
                        )]

                    [#break]

                [#case "output"]

                    [#local registryPath = formatRelativePath(
                        "s3://",
                        registryEndpoint,
                        imageFormat,
                        (getActiveLayer(PRODUCT_LAYER_TYPE).Name)!getActiveLayer(TENANT_LAYER_TYPE).Name,
                        resource.Name
                    )]
                    [#local imageLocation = formatRelativePath(
                        registryPath,
                        resource.Reference,
                        imageFileName
                    )]
                    [#break]

                [#default]
                    [#local registryPath = formatRelativePath(
                        "s3://",
                        registryEndpoint,
                        imageFormat,
                        (getActiveLayer(PRODUCT_LAYER_TYPE).Name)!getActiveLayer(TENANT_LAYER_TYPE).Name,
                        resource.Name
                    )]
                    [#local imageLocation = formatRelativePath(
                        registryPath,
                        imageFileName
                    )]
            [/#switch]

            [#switch resource.Source]
                [#case "url"]
                    [#local sourceLocation = imageConfiguration["Source:url"].Url]
                    [#local resource = mergeObjects(resource, { "Reference": imageConfiguration["Source:url"].ImageHash })]

                    [#local registryPath = formatRelativePath(
                        "s3://",
                        registryEndpoint,
                        imageFormat,
                        (getActiveLayer(PRODUCT_LAYER_TYPE).Name)!getActiveLayer(TENANT_LAYER_TYPE).Name,
                        resource.Name
                    )]
                    [#local imageLocation = formatRelativePath(
                        registryPath,
                        resource.Reference,
                        imageFileName
                    )]

                    [#break]
            [/#switch]
            [#break]

        [#case "docker"]

            [#local registryEndpoint = getActiveLayerAttributes(["ProviderId"], [ACCOUNT_LAYER_TYPE], "")[0] + ".dkr.ecr.ap-southeast-2.amazonaws.com" ]

            [#switch referenceSource]

                [#case "setting"]

                    [#local registryPath = formatRelativePath(
                        registryEndpoint,
                        formatName(
                            getOccurrenceBuildProduct(occurrence, getActiveLayer(PRODUCT_LAYER_TYPE).Name),
                            getOccurrenceBuildScopeExtension(occurrence)
                        ),
                        resource.Name
                    )]

                    [#local imageLocation = formatName(registryPath, resource.Reference)]
                    [#break]

                [#default]
                    [#local registryPath = formatRelativePath(
                            registryEndpoint,
                            resource.Name
                        )]

                    [#local imageLocation = "${registryPath}:${(resource.Reference)!''}"]
                    [#break]
            [/#switch]

            [#switch resource.Source]
                [#case "containerregistry"]
                    [#local sourceLocation = imageConfiguration["Source:ContainerRegistry"].Image ]
                    [#break]
            [/#switch]
            [#break]

        [#case "rdssnapshot"]
            [#local ImageLocation =
                        formatName(
                            imageFormat,
                            "rdssnapshot",
                            productId,
                            dataSetDeploymentUnit,
                            buildReference
                        )]
            [#break]
    [/#switch]

    [#return { id : mergeObjects(
            resource,
            {
                "RegistryPath" : registryPath,
                "ImageLocation" : imageLocation,
                "ImageFileName": imageFileName,
                "SourceLocation" : sourceLocation
            }
        )
    }]
[/#function]

[#function getAWSImageBuildScript filesArrayName region image]
    [#return
        [
            "copyFilesFromBucket" + " " +
                region + " " +
                image.ImageLocation?keep_after("s3://")?keep_before("/") + " " +
                image.ImageLocation?keep_after("s3://")?keep_after("/") + " " +
                "\"$\{tmpdir}\" || return $?",
            "#",
            "addToArray" + " " +
               filesArrayName + " " +
               "\"$\{tmpdir}/" + image.ImageFileName + "\"",
            "#"
        ] ]
[/#function]

[#function getAWSImageFromUrlScript image createZip=false]
    [#return
        [
            r'if [[ "${HAMLET_SKIP_IMAGE_PULL}" != "true" ]]; then',
            r'   get_url_image_to_registry ' +
            r'     "' + image.SourceLocation + r'" ' +
            r'     "' + ((image.Reference)!"") + r'" ' +
            r'     "' + image.RegistryPath + r'" ' +
            r'     "' + image.ImageFileName + r'" ' +
            r'     "' + createZip?c + r'" || exit $?',
            r'   # refresh settings to include new build file',
            r'',
            r'   assemble_settings "${GENERATION_DATA_DIR}" "${COMPOSITE_SETTINGS}"'
            r'else',
            r'   info "Skipping image pull as HAMLET_SKIP_IMAGE_PULL is set"',
            r'fi'
        ]
    ]
[/#function]

[#function getAWSImageFromContainerRegistryScript
        imageName
        sourceImage
        registryImage
        region
    ]

    [#return
        [
            r'if [[ "${HAMLET_SKIP_IMAGE_PULL}" != "true" ]]; then',
            r'  get_image_from_container_registry' +
            r'   "' + sourceImage + r'" ' +
            r'   "' + registryImage?keep_before("/") + r'" ' +
            r'   "' + "ecr" + r'" ' +
            r'   "' + region + r'" ' +
            r'   "' + registryImage + r'" || exit $?',
            r'   # refresh settings to include new build file',
            r'',
            r'   assemble_settings "${GENERATION_DATA_DIR}" "${COMPOSITE_SETTINGS}"',
            r'else',
            r'   info "Skipping image pull as HAMLET_SKIP_IMAGE_PULL is set"',
            r'fi'
        ]
    ]
[/#function]
