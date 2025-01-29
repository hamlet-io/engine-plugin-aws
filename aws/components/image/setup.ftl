[#ftl]

[#macro aws_image_cf_deployment_generationcontract_application occurrence ]
    [@addDefaultGenerationContract
        subsets=["deploymentcontract", "template", "epilogue" ]
    /]
[/#macro]

[#macro aws_image_cf_deployment_deploymentcontract occurrence ]
    [@addDefaultAWSDeploymentContract epilogue=true /]
[/#macro]

[#macro aws_image_cf_deployment_application occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources]

    [#local baselineLinks = getBaselineLinks(occurrence, [ "Encryption" ]) ]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local encryptionKeyId = baselineComponentIds[ "Encryption" ]!""]

    [#local image =  getOccurrenceImage(occurrence)]

    [#local invalidImageFormatSource = false]

    [#local contextLinks = getLinkTargets(occurrence) ]
    [#local _context =
        {
            "Links" : contextLinks,
            "LifecylePolicy" : {}
        }
    ]
    [#local _context = invokeExtensions( occurrence, _context )]

    [#if solution.Format == "docker" ]
        [#local repository = resources["containerRepository"]]

        [#if deploymentSubsetRequired(IMAGE_COMPONENT_TYPE, true)]

            [#local dockerConfig = solution["Format:docker"] ]

            [#local lifecyclePolicy = {}]
            [#switch dockerConfig.Lifecycle.ConfiguratonSource]
                [#case "Solution"]
                    [#local rules = []]

                    [#if dockerConfig.Lifecycle.Expiry.UntaggedMaxCount > 0 ]

                        [#local rules = combineEntities(
                            rules,
                            [
                                {
                                    "rulePriority": 1,
                                    "description": "Keep a number limited set of untagged image, expire all others",
                                    "selection": {
                                        "tagStatus": "untagged",
                                        "countType": "imageCountMoreThan",
                                        "countNumber": dockerConfig.Lifecycle.Expiry.UntaggedMaxCount
                                    },
                                    "action": {
                                        "type": "expire"
                                    }
                                }
                            ]
                        )]
                    [/#if]

                    [#if (dockerConfig.Lifecycle.Expiry.UntaggedDays)?is_string || dockerConfig.Lifecycle.Expiry.UntaggedDays > 0 ]

                        [#local untaggedDaysExpiry = dockerConfig.Lifecycle.Expiry.UntaggedDays]

                        [#if untaggedDaysExpiry?is_string ]
                            [#switch untaggedDaysExpiry ]
                                [#case "_operations" ]
                                    [#local untaggedDaysExpiry = operationsExpiration]
                                    [#break ]

                                [#default]
                                    [@fatal
                                        message="Invalid expiry value"
                                        detail="Supports a number of days or _operations"
                                        context={
                                            "Name": occurrence.Core.FullRawName,
                                            "ImageConfiguration" : dockerConfig
                                        }
                                    /]
                            [/#switch]
                        [/#if]

                        [#local rules = combineEntities(
                            rules,
                            [
                                {
                                    "rulePriority": 2,
                                    "description": "Expire untagged images after time",
                                    "selection": {
                                        "tagStatus": "untagged",
                                        "countType": "sinceImagePushed",
                                        "countUnit": "days",
                                        "countNumber": untaggedDaysExpiry
                                    },
                                    "action": {
                                        "type": "expire"
                                    }
                                }
                            ]
                        )]
                    [/#if]


                    [#if dockerConfig.Lifecycle.Expiry.TaggedMaxCount > 0 ]
                        [#local rules = combineEntities(
                            rules,
                            [
                                {
                                    "rulePriority": 10,
                                    "description": "Keep a number limited set of tagged images, expire all others",
                                    "selection": {
                                        "tagStatus": "tagged",
                                        "tagPatternList": ["*"],
                                        "countType": "imageCountMoreThan",
                                        "countNumber": dockerConfig.Lifecycle.Expiry.TaggedMaxCount
                                    },
                                    "action": {
                                        "type": "expire"
                                    }
                                }
                            ]
                        )]
                    [/#if]

                    [#if rules?has_content ]
                        [#local lifecyclePolicy = {
                            "rules" : rules
                        }]
                    [/#if]

                    [#break]

                [#case "Extension"]
                    [#local lifecyclePolicy = _context.LifecyclePolicy ]
                    [#break]
            [/#switch]


            [@createECRRepository
                id=repository.Id
                name=repository.Name
                scanOnPush=dockerConfig.Scanning.Enabled
                encryptionEnabled=dockerConfig.Encryption.Enabled
                encryptionKeyId=(dockerConfig.Encryption["aws:EncryptionSource"] == "EncryptionService")?then(
                    encryptionKeyId,
                    ""
                )
                encryptionType=(dockerConfig.Encryption["aws:EncryptionSource"] == "EncryptionService")?then(
                    "KMS",
                    "AES256"
                )
                immutableTags=dockerConfig.ImmutableTags
                tags=getOccurrenceTags(occurrence)
                lifecyclePolicy=lifecyclePolicy
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
                [#case "Local"]
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
                    [#break]

                [#case "ContainerRegistry"]
                    [#if deploymentSubsetRequired("epilogue", false)]
                        [@addToDefaultBashScriptOutput
                            content=[
                                r'case ${STACK_OPERATION} in',
                                r'  create|update)',
                                '       source_image="${solution["Source:ContainerRegistry"]["Image"]}"',
                                r'      destination_repository_url="$(get_cloudformation_stack_output "' + getRegion() + r'" "${STACK_NAME}" "' + repository.Id + r'" "url" || return $?)"',
                                r'      destination_repository_name="$(get_cloudformation_stack_output "' + getRegion() + r'" "${STACK_NAME}" "' + repository.Id + r'" "ref" || return $?)"',
                                r'',
                                r'      if docker info &>/dev/null; then',
                                '           aws --region "${getRegion()}" ecr get-login-password \\',
                                r'              | docker login --username AWS \',
                                r'              --password-stdin "${destination_repository_url%/*}" || return $?',
                                r'          docker pull "${source_image}" || return $?',
                                r'          tag="$(for i in $(docker inspect "${source_image}" --format ' + r"'{{join .RepoTags " + r'" "' + r"}}');" + r' do  [[ "${i}" =~ ^${source_image} ]] && echo "${i#*:}" && break; done)"',
                                r'          docker tag "${source_image}" "${destination_repository_url}:${tag}" || return $?',
                                r'          docker image push "${destination_repository_url}:${tag}" || return $?',
                                r'          digest="$(aws ecr --region "' + "${getRegion()}" + r'" batch-get-image --repository-name "${destination_repository_name}" --image-ids "imageTag=${tag}" --query "images[0].imageId.imageDigest" --output text)"',
                                r'          echo "digest: ${digest}"',
                                r'      else',
                                r'          warning "docker not found to pull image - skipping pull"',
                                r'      fi',
                                r'esac'
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
                [#case "Local"]
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
