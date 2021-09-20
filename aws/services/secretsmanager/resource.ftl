[#ftl]

[#function getSecretManagerSecretRef secretId secretKey ]
    [#return
        {
            "Fn::Sub": [
                r'{{resolve:secretsmanager:${secretId}:SecretString:${secretKey}}}',
                {
                    "secretId": getReference(secretId),
                    "secretKey" : secretKey
                }
            ]
        }
    ]
[/#function]

[#function getComponentSecretResources occurrence secretId secretName secretDescription="" ]
    [#return {
        "secret" : {
            "Id" : formatResourceId(AWS_SECRETS_MANAGER_SECRET_RESOURCE_TYPE, occurrence.Core.Id, secretId),
            "Name" : formatName(occurrence.Core.FullName, secretName),
            "Description" : secretDescription,
            "Type" : AWS_SECRETS_MANAGER_SECRET_RESOURCE_TYPE
        }
    }]
[/#function]

[#function getSecretsManagerPolicyFromComponentConfig secretSolutionConfig ]
    [#local requirements = secretSolutionConfig.Requirements ]
    [#return
        getSecretsManagerSecretGenerationPolicy(
            requirements.MinLength,
            secretSolutionConfig.Generated.SecretKey,
            secretSolutionConfig.Generated.Content,
            requirements.ExcludedCharacters?join(""),
            !(requirements.IncludeUpper),
            !(requirements.IncludeLower),
            !(requirements.IncludeNumber),
            !(requirements.IncludeSpecial),
            false,
            requirements.RequireAllIncludedTypes
        )
    ]
[/#function]

[#function getSecretsManagerSecretGenerationPolicy
        passwordLength
        generateStringKey
        secretTemplate
        excludeChars=""
        excludeLowercase=false
        excludeUppercase=false
        excludeNumbers=false
        excludePunctuation=false
        includeSpace=false
        requireEachType=true
    ]
    [#return
        {
            "SecretStringTemplate" : getJSON(secretTemplate),
            "GenerateStringKey" : generateStringKey,
            "PasswordLength" : passwordLength,
            "ExcludeLowercase" : excludeLowercase,
            "ExcludeNumbers" : excludeNumbers,
            "ExcludePunctuation" : excludePunctuation,
            "ExcludeUppercase" : excludeUppercase,
            "IncludeSpace" : includeSpace,
            "RequireEachIncludedType" : requireEachType
        } +
        attributeIfContent(
            "ExcludeCharacters",
            excludeChars
        )
    ]
[/#function]

[#macro createSecretsManagerSecret
        id
        name
        tags
        kmsKeyId=""
        description=""
        generateSecret=true
        generateSecretPolicy={}
        secretString=""
    ]

    [@cfResource
        id=id
        type="AWS::SecretsManager::Secret"
        properties=
            {
                "Name" : name
            } +
            attributeIfContent(
                "KmsKeyId",
                kmsKeyId,
                getReference(kmsKeyId, ARN_ATTRIBUTE_TYPE)
            ) +
            attributeIfContent(
                "Description",
                description
            ) +
            generateSecret?then(
                {
                    "GenerateSecretString" : generateSecretPolicy
                },
                attributeIfContent(
                    "SecretString",
                    secretString
                )
            )
        tags=tags
    /]
[/#macro]


[#macro setupComponentSecret
            occurrence
            secretStoreLink
            kmsKeyId
            secretComponentResources={}
            secretComponentConfiguration={}
            componentType=""
            secretString="" ]

    [#local secretStoreCore = secretStoreLink.Core ]
    [#local secretStoreSolution = secretStoreLink.Configuration.Solution ]
    [#local secretStoreResources = secretStoreLink.State.Resources ]

    [#if secretStoreCore.Type != SECRETSTORE_COMPONENT_TYPE ]
        [@fatal
            message="Secret Store link is to the wrong component"
            detail="Secret store must be a ${SECRETSTORE_COMPONENT_TYPE} component"
            context={
                "Id" : secretStoreCore.Id,
                "Type" : secretStoreCore.Type
            }
        /]

    [#else]
        [#local resources = secretComponentResources?has_content?then(
                            secretComponentResources,
                            occurrence.State.Resources
        )]

        [#local solution = secretComponentConfiguration?has_content?then(
                                secretComponentConfiguration,
                                occurrence.Configuration.Solution.Secret
        )]

        [#local componentType = componentType?has_content?then(
                                componentType,
                                occurrence.Core.Type
        )]

        [#local generateSecret = (solution.Source == "generated") ]
        [#local secretKeyPath = "." ]
        [#local secretAttribute = SECRET_ATTRIBUTE_TYPE]

        [#if generateSecret ]
            [#local secretAttribute = GENERATEDPASSWORD_ATTRIBUTE_TYPE ]
            [#local secretKeyPath = (solution.Generated.SecretKey)?ensure_starts_with(".") ]
        [/#if]

        [#switch secretStoreSolution.Engine ]
            [#case "aws:secretsmanager" ]
                [#local secretId = resources["secret"].Id ]
                [#local secretName = resources["secret"].Name ]
                [#local secretDescription = resources["secret"].Description ]

                [#if deploymentSubsetRequired(componentType, true) ]

                    [#local secretPolicy = getSecretsManagerPolicyFromComponentConfig(solution)]
                    [@createSecretsManagerSecret
                        id=secretId
                        name=secretName
                        tags=getOccurrenceCoreTags(occurrence, secretName)
                        kmsKeyId=kmsKeyId
                        description=secretDescription
                        generateSecret=generateSecret
                        generateSecretPolicy=secretPolicy
                        secretString=secretString
                    /]
                [/#if]
                [#if deploymentSubsetRequired("epilogue", false) ]
                    [@addToDefaultBashScriptOutput
                        content=
                        [
                            r'case ${STACK_OPERATION} in',
                            r'  create|update)',
                            r'    info "Saving secret to CMDB"',
                            r'    secret_arn="$(get_cloudformation_stack_output "' + regionId + r'" ' + r' "${STACK_NAME}" ' + secretId + r' "ref" || return $?)"',
                            r'    secret_content="$(aws --region "' + regionId + r'" --output text secretsmanager get-secret-value --secret-id "${secret_arn}" --query "SecretString" || return $?)"',
                            r'    secret_value="$( echo "${secret_content}" | jq -r "' + secretKeyPath + r'")"',
                            r'    kms_encrypted_secret="$(encrypt_kms_string "' + regionId + r'" ' + r' "${secret_value}" ' + r' "' + getExistingReference(kmsKeyId, ARN_ATTRIBUTE_TYPE) + r'" || return $?)"'
                        ] +
                        pseudoStackOutputScript(
                            "KMS Encrypted Secret",
                            {
                                formatId(secretId, secretAttribute) : r'${kms_encrypted_secret}'
                            },
                            secretId
                        ) +
                        [
                            "esac"
                        ]
                    /]
                [/#if]
                [#break]
        [/#switch]
    [/#if]
[/#macro]
