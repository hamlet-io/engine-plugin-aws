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

    [#local image =  getOccurrenceImage(occurrence)]

    [#local invalidImageFormatSource = false]

    [#if solution.Format == "docker" ]
        [#local repository = resources["containerRepository"]]

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
        [#case "openapi"]

            [#switch solution.Source]
                [#case "registry"]
                    [#break]
                [#case "url"]
                    [#if deploymentSubsetRequired("epilogue", false)]
                        [@addToDefaultBashScriptOutput
                            content=getAWSImageFromUrlScript(image, true)
                        /]
                    [/#if]
                    [#break]

                [#default]
                     [#local invalidImageFormatSource = true]
            [/#switch]

            [#break]

        [#case "docker"]

            [#switch solution.Source]
                [#case "Local"]
                [#local "registry"]
                    [#break]

                [#case "ContainerRegistry"]
                    [#if deploymentSubsetRequired("epilogue", false)]
                        [@addToDefaultBashScriptOutput
                            content=[
                                'source_image="${solution["Source:ContainerRegistry"]["Image"]}"',
                                r'destination_repository_url="$(get_cloudformation_stack_output "' + getRegion() + r'" "${STACK_NAME}" "' + repository.Id + r'" "url" || return $?)"',
                                r'destination_repository_name="$(get_cloudformation_stack_output "' + getRegion() + r'" "${STACK_NAME}" "' + repository.Id + r'" "ref" || return $?)"',
                                r'',
                                r'if docker info &>/dev/null; then',
                                '   aws --region "${getRegion()}" ecr get-login-password \\',
                                r'    | docker login --username AWS \',
                                r'       --password-stdin "${destination_repository_url%/*}" || return $?',
                                r'  docker pull "${source_image}" || return $?',
                                r'  tag="$(for i in $(docker inspect "${source_image}" --format ' + r"'{{join .RepoTags " + r'" "' + r"}}');" + r' do  [[ "${i}" =~ ^${source_image} ]] && echo "${i#*:}" && break; done)"',
                                r'  docker tag "${source_image}" "${destination_repository_url}:${tag}" || return $?',
                                r'  docker image push "${destination_repository_url}:${tag}" || return $?',
                                r'  digest="$(aws ecr --region "' + "${getRegion()}" + r'" batch-get-image --repository-name "${destination_repository_name}" --image-ids "imageTag=${tag}" --query "images[0].imageId.imageDigest" --output text)"',
                                r'  echo "digest: ${digest}"',
                                r'else',
                                r'  warning "docker not found to pull image - skipping pull"',
                                r'fi'
                            ]
                        /]
                    [/#if]
                    [#break]

                [#default]
                     [#local invalidImageFormatSource = true]
            [/#switch]

            [#break]

        [#case "lambda_jar" ]
            [#switch solution.Source]
                [#case "registry"]
                    [#break]
                [#case "url"]
                    [#if deploymentSubsetRequired("epilogue", false)]
                        [@addToDefaultBashScriptOutput
                            content=getAWSImageFromUrlScript(image, false)
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
