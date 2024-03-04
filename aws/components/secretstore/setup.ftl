[#ftl]

[#macro aws_secretstore_cf_deployment_generationcontract occurrence ]
    [@addDefaultGenerationContract subsets=[ "deploymentcontract", "template", "epilogue" ] /]
[/#macro]

[#macro aws_secretstore_cf_deployment_deploymentcontract occurrence ]
    [@addDefaultAWSDeploymentContract epilogue=true /]
[/#macro]

[#macro aws_secretstore_cf_deployment occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]

    [#local engine = solution.Engine ]

    [#-- Baseline lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "Encryption"] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]

    [#local cmkKeyId = (baselineComponentIds["Encryption"])!"HamletWarning:MissingKey"]

    [#list (occurrence.Occurrences![])?filter(x -> x.Configuration.Solution.Enabled ) as subOccurrence]

        [#local core = subOccurrence.Core ]
        [#local solution = subOccurrence.Configuration.Solution]
        [#local resources = subOccurrence.State.Resources]

        [#local secretString = ""]
        [#local generationPolicy = {}]

        [#local generateSecret = solution.Source == "generated" ]

        [#if generateSecret ]
            [#local secretString = solution.Generated.SecretKey ]
            [#local generationPolicy = getSecretsManagerPolicyFromComponentConfig(solution)]
        [/#if]

        [#switch engine ]
            [#case "aws:secretsmanager" ]

                [#local secret = resources["secret"]]


                [#if deploymentSubsetRequired(SECRETSTORE_COMPONENT_TYPE, true)]

                    [@createSecretsManagerSecret
                        id=secret.Id
                        name=secret.Name
                        tags=getOccurrenceTags(subOccurrence)
                        kmsKeyId=cmkKeyId
                        description=solution.Description
                        generateSecret=(solution.Source == "generated")
                        generateSecretPolicy=generationPolicy
                        secretString=secretString
                    /]
                [/#if]

                [@saveSecretValueAsKMSStringScript
                    secretId=secret.Id
                    secretAttribute=SECRET_ATTRIBUTE_TYPE
                    kmsKeyId=cmkKeyId
                    subset="epilogue"
                /]

                [#break]

        [/#switch]

    [/#list]
[/#macro]
