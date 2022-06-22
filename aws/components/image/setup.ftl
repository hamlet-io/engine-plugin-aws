[#ftl]

[#macro aws_image_cf_deployment_generationcontract_application occurrence ]
    [@addDefaultGenerationContract
        subsets=["template", "epilogue" ]
    /]
[/#macro]

[#macro aws_image_cf_deployment_application occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources]

    [#local image = resources["image"]]

    [#local invalidImageFormatSource = false]

    [#if solution.Format == "docker" ]
        [#local repository = resources["repository"]]

        [#if deploymentSubsetRequired(IMAGE_COMPONENT_TYPE, true)]
            [@createECRRepository
                id=repository.Id
                name=repository.Name
                scanOnPush=false
                encryptionEnabled=false
                tags=getOccurrenceTags(occurrence)
            /]
        [/#if]
    [/#if]

    [#switch solution.Format]
        [#case "scripts"]
        [#case "spa"]
        [#case "dataset"]
        [#case "lambda"]
        [#case "contentnode"]
        [#case "pipeline"]

            [#switch solution.Source]
                [#case "Registry"]
                    [#break]
                [#case "URL"]
                    [#if deploymentSubsetRequired("epilogue", false)]
                        [@addToDefaultBashScriptOutput
                            content=
                                getImageFromUrlScript(
                                    getRegion(),
                                    productName,
                                    environmentName,
                                    segmentName,
                                    occurrence,
                                    solution.Image["source:URL"].URL,
                                    solution.Format,
                                    "${solution.Format}.zip",
                                    occurrence.Core.RawName,
                                    solution.Image["source:URL"].ImageHash,
                                    true
                                )
                        /]
                    [/#if]
                    [#break]

                [#default]
                     [#local invalidImageFormatSource = true]
            [/#switch]

            [#break]

        [#case "docker"]

            [#switch solution.Source]
                [#case "Registry"]
                    [#break]

                [#case "ContainerRegistry"]
                    [#if deploymentSubsetRequired("epilogue", false)]
                        [@addToDefaultBashScriptOutput
                            content=
                                getImageFromContainerRegistryScript(
                                    productName,
                                    environmentName,
                                    segmentName,
                                    occurrence,
                                    solution["Source:ContainerRegistry"].Image,
                                    "docker",
                                    getRegistryEndPoint("docker", occurrence),
                                    "ecr",
                                    getRegion(),
                                    "",
                                    image.Registry
                                )
                        /]
                    [/#if]
                    [#break]

                [#default]
                     [#local invalidImageFormatSource = true]
            [/#switch]

            [#break]

        [#case "lambda_jar" ]
            [#switch solution.Source]
                [#case "Registry"]
                    [#break]
                [#case "URL"]
                    [#if deploymentSubsetRequired("epilogue", false)]
                        [@addToDefaultBashScriptOutput
                            content=
                                getImageFromUrlScript(
                                    getRegion(),
                                    productName,
                                    environmentName,
                                    segmentName,
                                    occurrence,
                                    solution.Image["source:URL"].URL,
                                    solution.Format,
                                    "${solution.Format}.jar",
                                    occurrence.Core.RawName,
                                    solution.Image["source:URL"].ImageHash,
                                    false
                                )
                        /]
                    [/#if]
                    [#break]

                [#default]
                     [#local invalidImageFormatSource = true]
            [/#switch]

            [#break]

        [#case "openapi"]
            [#switch solution.Source]
                [#case "Registry"]
                    [#break]

                [#case "URL"]
                    [#if deploymentSubsetRequired("epilogue", false)]
                        [@addToDefaultBashScriptOutput
                            content=
                                getImageFromUrlScript(
                                    getRegion(),
                                    productName,
                                    environmentName,
                                    segmentName,
                                    occurrence,
                                    solution.Image["source:URL"].URL,
                                    solution.Format,
                                    "${solution.Format}.zip",
                                    occurrence.Core.RawName,
                                    solution.Image["source:URL"].ImageHash,
                                    true
                                )
                        /]
                    [/#if]
                    [#break]

                [#default]
                     [#local invalidImageFormatSource = true]
            [/#switch]
            [#break]
    [/#switch]

    [#if invalidImageFormatSource ]
        [@fatal
            message="Invalid source for image format"
            detail={
                "Source": solution.Source,
                "Format": solution.Format,
                "Id": occurrence.Core.RawId
            }
        /]
    [/#if]
[/#macro]
