[#ftl]
[#macro aws_template_cf_deployment_generationcontract_application occurrence ]
    [@addDefaultGenerationContract subsets=[ "pregeneration", "prologue", "template" ] /]
[/#macro]

[#macro aws_template_cf_deployment_application occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]

    [#local templateId = resources["template"].Id ]

    [#local baselineLinks = getBaselineLinks(occurrence, [ "OpsData", "AppData", "Encryption" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]

    [#local operationsBucket = getExistingReference(baselineComponentIds["OpsData"], NAME_ATTRIBUTE_TYPE )]
    [#local operationsBucketFQDN = getExistingReference(baselineComponentIds["OpsData"], DNS_ATTRIBUTE_TYPE)]
    [#local dataBucket = getExistingReference(baselineComponentIds["AppData"], NAME_ATTRIBUTE_TYPE )]
    [#local kmsKeyArn = getExistingReference(baselineComponentIds["Encryption"], ARN_ATTRIBUTE_TYPE )]

    [#local templatePath = formatRelativePath(
        getOccurrenceSettingValue(occurrence, "SETTINGS_PREFIX"),
        "templates"
    )]

    [#local templateRootFileUrl = {
                                    "Fn::Join" : [
                                        "/",
                                        [
                                            "https://${operationsBucketFQDN}"
                                            templatePath,
                                            solution.RootFile
                                        ]
                                    ]
                                }]

    [#local buildReference = getOccurrenceBuildReference(occurrence)]
    [#local buildUnit = getOccurrenceBuildUnit(occurrence)]

    [#local imageSource = solution.Image.Source]
    [#if imageSource == "url" ]
        [#local buildUnit = occurrence.Core.Name ]
    [/#if]

    [#if deploymentSubsetRequired("pregeneration", false) && imageSource == "url" ]
        [@addToDefaultBashScriptOutput
            content=
                getImageFromUrlScript(
                    getRegion(),
                    productName,
                    environmentName,
                    segmentName,
                    occurrence,
                    solution.Image.UrlSource.Url,
                    "scripts",
                    "scripts.zip",
                    solution.Image.UrlSource.ImageHash,
                    true
                )
        /]
    [/#if]

    [#if deploymentSubsetRequired("prologue", false) ]
        [@addToDefaultBashScriptOutput
            content=
                getBuildScript(
                    "cfnTemplates",
                    getRegion(),
                    "scripts",
                    productName,
                    occurrence,
                    "scripts.zip",
                    buildUnit
                ) +
                syncFilesToBucketScript(
                    "cfnTemplates",
                    getRegion(),
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
            [#local vpc = getExistingReference(vpcId)]

            [#local subnets = getSubnets(core.Tier, networkResources, "", false)]

        [/#if]

        [#local contextLinks = getLinkTargets(occurrence) ]
        [#local _context =
            {
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
                "KmsKeyArn" : kmsKeyArn,
                "Parameters" : parameters
            } +
            solution.NetworkAccess?then(
                {
                    "VpcId" : vpc,
                    "Subnets" : subnets?join(",")
                },
                {}
            )
        ]

        [#-- Add in extension specifics including override of defaults --]
        [#local _context = invokeExtensions( occurrence, _context )]
        [#local parameters += (getFinalEnvironment(occurrence, _context )["Environment"])!{} ]
        [#local parameters += _context.Parameters ]

        [#-- Map Template outputs into our standard attributes --]
        [#local outputs = {}]

        [#list solution.Attributes as id,attribute ]

            [#if attribute.IdSuffix?has_content ]
                [#local attributeId = formatAttributeId(formatId(templateId, attribute.IdSuffix), attribute.AttributeType)]

                [@cfOutput
                    id=attributeId
                    value={
                        "Fn::GetAtt" : [
                            templateId,
                            concatenate( [ "Outputs", attribute.TemplateOutputKey ], ".")
                        ]
                    }
                /]

            [#else]
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

                    }
                )]
            [/#if]


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
