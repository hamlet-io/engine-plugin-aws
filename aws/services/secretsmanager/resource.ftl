[#ftl]

[#assign SECRETS_MANAGER_SECRET_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        REGION_ATTRIBUTE_TYPE: {
            "Value" : { "Ref" : "AWS::Region" }
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_SECRETS_MANAGER_SECRET_RESOURCE_TYPE
    mappings=SECRETS_MANAGER_SECRET_OUTPUT_MAPPINGS
/]

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

[#function getComponentSecretResources occurrence secretId secretName cmkKeyId provider secretDescription="" ]
    [#return {
        "secret" : {
            "Id" : formatResourceId(AWS_SECRETS_MANAGER_SECRET_RESOURCE_TYPE, occurrence.Core.Id, secretId),
            "Name" : formatName(occurrence.Core.FullName, secretName),
            "Description" : secretDescription,
            "Type" : AWS_SECRETS_MANAGER_SECRET_RESOURCE_TYPE,
            "cmkKeyId" : cmkKeyId,
            "Provider" : provider
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
        outputs=SECRETS_MANAGER_SECRET_OUTPUT_MAPPINGS
    /]
[/#macro]

[#macro saveSecretValueAsKMSStringScript
            secretId
            secretAttribute
            kmsKeyId
            secretKeyJSONPath=""
            subset="epilogue" ]
    [#if deploymentSubsetRequired(subset, false) ]
        [@addToDefaultBashScriptOutput
            content=
            [
                r'case ${STACK_OPERATION} in',
                r'  create|update)',
                r'    secret_arn="$(get_cloudformation_stack_output "' + getRegion() + r'" ' + r' "${STACK_NAME}" ' + secretId + r' "ref" || return $?)"',
                r'    if [[ -n "$( aws --region "' + getRegion() + r'" --output text secretsmanager list-secret-version-ids --secret-id "${secret_arn}" --query "Versions[*].VersionId")" ]]; then ',
                r'       secret_content="$(aws --region "' + getRegion() + r'" --output text secretsmanager get-secret-value --secret-id "${secret_arn}" --query "SecretString" || return $?)"',
                r'       if [[ -n "${secret_content}" ]]; then'
                r'            info "Saving secret to CMDB"'
            ] +
            secretKeyJSONPath?has_content?then(
                [
                    r'        secret_value="$( echo "${secret_content}" | jq -r "' + secretKeyJSONPath + r'")"'
                ],
                [
                    r'        secret_value="${secret_content}"'
                ]
            ) +
            [
                r'            kms_encrypted_secret="$(encrypt_kms_string "' + getRegion() + r'" ' + r' "${secret_value}" ' + r' "' + getExistingReference(kmsKeyId, ARN_ATTRIBUTE_TYPE) + r'" || return $?)"'
            ] +
            pseudoStackOutputScript(
                "KMS Encrypted Secret",
                {
                    formatId(secretId, secretAttribute) : r'${kms_encrypted_secret}'
                },
                secretId
            ) +
            [
                r'       else',
                r'           info "secret emtpy - skipping cmdb save"',
                r'       fi',
                r'   else',
                r'     info "secret emtpy - skipping cmdb save"',
                r'   fi',
                r' esac'
            ]
        /]
    [/#if]
[/#macro]


[#macro setupComponentGeneratedSecret
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

        [#local secretAttribute = GENERATEDPASSWORD_ATTRIBUTE_TYPE ]
        [#local secretKeyPath = (solution.Generated.SecretKey)?has_content?then(
                                    (solution.Generated.SecretKey)?ensure_starts_with("."),
                                    "") ]

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
                        generateSecret=true
                        generateSecretPolicy=secretPolicy
                        secretString=secretString
                    /]
                [/#if]

                [@saveSecretValueAsKMSStringScript
                    secretId=secretId
                    secretAttribute=secretAttribute
                    kmsKeyId=kmsKeyId
                    secretKeyJSONPath=secretKeyPath
                /]

                [#break]
        [/#switch]
    [/#if]
[/#macro]
