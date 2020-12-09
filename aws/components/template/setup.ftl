[#ftl]
[#macro aws_template_cf_deployment_generationcontract_application occurrence ]
    [@addDefaultGenerationContract subsets=[ "prologue", "template" ] /]
[/#macro]

[#macro aws_template_cf_deployment_application occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]

    [#local templateId = resources["template"].Id ]

    [#local baselineLinks = getBaselineLinks(occurrence, [ "OpsData", "AppData", "Encryption" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]

    [#local operationsBucket = getExistingReference(AWS_PROVIDER, baselineComponentIds["OpsData"], NAME_ATTRIBUTE_TYPE )]
    [#local dataBucket = getExistingReference(AWS_PROVIDER, baselineComponentIds["AppData"], NAME_ATTRIBUTE_TYPE )]
    [#local kmsKeyArn = getExistingReference(AWS_PROVIDER, baselineComponentIds["Encryption"], ARN_ATTRIBUTE_TYPE )]

    [#local templatePath = formatRelativePath(
        getOccurrenceSettingValue(occurrence, "SETTINGS_PREFIX"),
        "templates"
    )]

    [#local templateRootFileUrl = formatRelativePath(
                                    "https://s3.amazonaws.com/",
                                    operationsBucket,
                                    templatePath,
                                    solution.RootFile
                                )]

    [#if deploymentSubsetRequired("prologue", false) ]
        [@addToDefaultBashScriptOutput
            content=
                getBuildScript(
                    "cfnTemplates",
                    regionId,
                    "scripts",
                    productName,
                    occurrence,
                    "scripts.zip"
                ) +
                syncFilesToBucketScript(
                    "cfnTemplates",
                    regionId,
                    operationsBucket,
                    templatePath
                )
        /]
    [/#if]

    [#if deploymentSubsetRequired(TEMPLATE_COMPONENT_TYPE, true)]

        [#-- Input parameters to the template --]
        [#local parameters = {}]

        [#list solution.Parameters as id,parameter ]
            [#local parameters = mergeObjects(
                                    parameters,
                                    {
                                        parameter.Key : parameter.Value
                                    }

            )]
        [/#list]

        [#if solution.NetworkAccess ]
            [#local networkLink = getOccurrenceNetwork(occurrence).Link!{} ]

            [#local networkLinkTarget = getLinkTarget(occurrence, networkLink ) ]
            [#if ! networkLinkTarget?has_content ]
                [@fatal message="Network could not be found" context=networkLink /]
                [#return]
            [/#if]

            [#local networkConfiguration = networkLinkTarget.Configuration.Solution]
            [#local networkResources = networkLinkTarget.State.Resources ]

            [#local vpcId = networkResources["vpc"].Id ]
            [#local vpc = getExistingReference(AWS_PROVIDER, vpcId)]

            [#local subnets = getSubnets(AWS_PROVIDER, core.Tier, networkResources, "", false)]

        [/#if]

        [#local fragment = getOccurrenceFragmentBase(occurrence) ]

        [#local contextLinks = getLinkTargets(occurrence) ]
        [#assign _context =
            {
                "Id" : fragment,
                "Name" : fragment,
                "Instance" : core.Instance.Id,
                "Version" : core.Version.Id,
                "DefaultEnvironment" : defaultEnvironment(occurrence, contextLinks, baselineLinks),
                "Environment" : {},
                "Links" : contextLinks,
                "BaselineLinks" : baselineLinks,
                "DefaultCoreVariables" : false,
                "DefaultEnvironmentVariables" : false,
                "DefaultLinkVariables" : false,
                "DefaultBaselineVariables" : false,
                "OpsDataBucketName" : operationsBucket,
                "AppDataBucketName" : dataBucket,
                "AppDataBucketPrefix" : getAppDataFilePrefix(occurrence),
                "KmsKeyArn" : kmsKeyArn
            } +
            solution.NetworkAccess?then(
                {
                    "VpcId" : vpc,
                    "Subnets" : subnets?join(",")
                },
                {}
            )
        ]

        [#-- Add in fragment specifics including override of defaults --]
        [#local fragmentId = formatFragmentId(_context)]
        [#include fragmentList?ensure_starts_with("/")]

        [#assign _context += getFinalEnvironment(occurrence, _context ) ]
        [#local parameters += _context.Environment ]

        [#-- Map Template outputs into our standard attributes --]
        [#local outputs = {}]

        [#list solution.Attributes as id,attribute ]
            [#local outputs = mergeObjects(
                outputs,
                {
                    attribute.AttributeType : {
                        "Value": {
                            "Fn::GetAtt" : [
                                templateId,
                                concatenate( [ "Outputs", attribute.TemplateOutputKey ], ".")
                            ]
                        }
                    }

                })]
        [/#list]

        [@createCFNNestedStack
            id=templateId
            parameters=parameters
            tags=getOccurrenceCoreTags(occurrence)
            tempalteUrl=templateRootFileUrl
            outputs=outputs
            dependencies=""
        /]
    [/#if]
[/#macro]
