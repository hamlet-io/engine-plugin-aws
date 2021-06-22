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
