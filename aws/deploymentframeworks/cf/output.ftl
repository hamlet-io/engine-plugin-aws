[#ftl]

[#function getCFTemplateCoreOutputs region={ "Ref" : "AWS::Region" } account={ "Ref" : "AWS::AccountId" } deploymentUnit=getCLODeploymentUnit() deploymentMode=getCLODeploymentMode() ]
    [#return {
        "Account" :{ "Value" : account },
        "Region" : {"Value" : region },
        "DeploymentUnit" : {
            "Value" :
                deploymentUnit +
                (
                    (!(ignoreDeploymentUnitSubsetInOutputs!false)) &&
                    (getCLODeploymentUnitSubset()?has_content)
                )?then(
                    "-" + getCLODeploymentUnitSubset()?lower_case,
                    ""
                )
        },
        "DeploymentMode" : { "Value" : deploymentMode }
    }]
[/#function]

[#function getCfTemplateCoreTags name="" tier="" component="" zone="" propagate=false flatten=false maxTagCount=-1]
    [#local result =
        [
            { "Key" : "cot:request", "Value" : getCLORequestReference() }
        ] +
        accountObject.CostCentre?has_content?then(
            [
                { "Key" : "cot:costcentre", "Value" : accountObject.CostCentre }
            ],
            []
        ) +
        [
            { "Key" : "cot:configuration", "Value" : getCLOConfigurationReference() },
            { "Key" : "cot:tenant", "Value" : tenantName },
            { "Key" : "cot:account", "Value" : accountName }
        ] +
        productId?has_content?then(
            [
                { "Key" : "cot:product", "Value" : productName }
            ],
            []
        ) +
        environmentId?has_content?then(
            [
                { "Key" : "cot:environment", "Value" : environmentName }
            ],
            []
        ) +
        [
            { "Key" : "cot:category", "Value" : categoryName }
        ] +
        segmentId?has_content?then(
            [
                { "Key" : "cot:segment", "Value" : segmentName }
            ],
            []
        ) +
        tier?has_content?then(
            [
                { "Key" : "cot:tier", "Value" : getTierName(tier) }
            ],
            []
        ) +
        component?has_content?then(
            [
                { "Key" : "cot:component", "Value" : getComponentName(component) }
            ],
            []
        ) +
        zone?has_content?then(
            [
                { "Key" : "cot:zone", "Value" : getZoneName(zone) }
            ],
            []
        ) +
        name?has_content?then(
            [
                { "Key" : "Name", "Value" : name }
            ],
            []
        )
    ]
    [#if propagate]
        [#local returnValue = []]
        [#list result as entry]
            [#local returnValue +=
                [
                    entry + {"PropagateAtLaunch" : "True" }
                ]
            ]
        [/#list]
        [#local result=returnValue]
    [/#if]
    [#if flatten ]
        [#local returnValue = {} ]
        [#list result as entry ]
            [#local returnValue +=
                {
                    entry.Key, entry.Value
                }
            ]
        [/#list]
        [#local result=returnValue]
    [/#if]

    [#if maxTagCount gte 0 ]
        [#local maxTagCount = ( maxTagCount -1 lt result?size )?then(
                                    maxTagCount,
                                    result?size
        )]
        [#local result=result[0..( maxTagCount -1 )]]
    [/#if]
    [#return result]
[/#function]

[#function getCfTemplateDefaultOutputs]
    [#return
        {
            REFERENCE_ATTRIBUTE_TYPE : {
                "UseRef" : true
            }
        }
    ]
[/#function]

[#macro cfOutput id value export=false ]
    [@mergeWithJsonOutput
        name="outputs"
        content=
            {
                id : {
                    "Value" : value
                } +
                export?then(
                    {
                        "Export" : {
                            "Name" : {
                                "Fn::Join" :
                                    [ ":", [ { "Ref" : "AWS::StackName" }, id ] ]
                            }
                        }
                    },
                    {}
                )
            }
    /]
[/#macro]

[#macro cfResource
            id
            type
            properties={}
            tags=[]
            outputs=getCfTemplateDefaultOutputs()
            outputId=""
            dependencies=[]
            metadata={}
            deletionPolicy=""
            updateReplacePolicy=""
            updatePolicy={}
            creationPolicy={}
    ]

    [#local localDependencies = [] ]
    [#list asArray(dependencies) as resourceId]
        [#if getReference(resourceId)?is_hash]
            [#local localDependencies += [resourceId] ]
        [/#if]
    [/#list]

    [@mergeWithJsonOutput
        name="resources"
        content=
            {
                id :
                    {
                        "Type" : type
                    } +
                    attributeIfContent("Metadata", metadata) +
                    attributeIfTrue(
                        "Properties",
                        properties?has_content || tags?has_content,
                        properties + attributeIfContent("Tags", tags)) +
                    attributeIfContent("DependsOn", localDependencies) +
                    attributeIfContent("DeletionPolicy", deletionPolicy) +
                    attributeIfContent("UpdateReplacePolicy", updateReplacePolicy) +
                    attributeIfContent("UpdatePolicy", updatePolicy) +
                    attributeIfContent("CreationPolicy", creationPolicy)
            }
    /]

    [#assign oId = outputId?has_content?then(outputId, id)]
    [#list outputs as type,value]
        [#if type == REFERENCE_ATTRIBUTE_TYPE]
            [@cfOutput
                oId,
                {
                    "Ref" : id
                },
                value.Export!false
            /]
        [#else]

            [#if value.Replace?has_content ]
                [#local content = getJSON(value.Replace)]
                [#list [ "_id_" ] as replaceString ]
                    [#switch replaceString ]
                        [#case "_id_" ]
                            [#local content = content?replace(replaceString, id )]
                            [#break]
                    [/#switch]
                [/#list]

                [@cfOutput
                    formatAttributeId(oId, type),
                    content?eval,
                    value.Export!false
                /]
            [#else]
                [@cfOutput
                    formatAttributeId(oId, type),
                    ((value.UseRef)!false)?then(
                        {
                            "Ref" : id
                        },
                        value.Value?has_content?then(
                            value.Value,
                            {
                                "Fn::GetAtt" : [id, value.Attribute]
                            }
                        )
                    ),
                    value.Export!false
                /]
            [/#if]


        [/#if]
    [/#list]
[/#macro]

[#macro cfParameter
            id
            type
            default=""
            description=""
            allowedPattern=""
            allowedValues=""
            constraintDescription=""
            maxLength=""
            maxValue=""
            minLength=""
            minValue=""
    ]

    [@mergeWithJsonOutput
        name="parameters"
        content=
            {
                id : {
                    "Type" : type
                } +
                attributeIfContent(
                    "AllowedPattern",
                    allowedPattern
                ) +
                attributeIfContent(
                    "AllowedValues",
                    allowedValues
                ) +
                attributeIfContent(
                    "ConstraintDescription",
                    constraintDescription
                ) +
                attributeIfContent(
                    "Default",
                    default
                ) +
                attributeIfContent(
                    "Description",
                    description
                ) +
                attributeIfContent(
                    "MaxLength",
                    maxLength
                ) +
                attributeIfContent(
                    "MaxValue",
                    maxValue
                ) +
                attributeIfContent(
                    "MinLength",
                    minLength
                ) +
                attributeIfContent(
                    "MinValue",
                    minValue
                )
            }
    /]
[/#macro]

[#function cf_output_resource level="" include=""]

    [@setOutputFileProperties format="json" /]

    [#-- Resources --]
    [#if include?has_content]
        [#include include?ensure_starts_with("/")]
    [#else]
        [@processFlows
            level=level
            framework=CLOUD_FORMATION_DEPLOYMENT_FRAMEWORK
            flows=getCLOFlows()
        /]
    [/#if]

    [#if getOutputContent("resources")?has_content ]
        [#return
            {
                "AWSTemplateFormatVersion" : "2010-09-09",
                "Metadata" :
                    {
                        "Prepared" : .now?iso_utc,
                        "RequestReference" : getCLORequestReference(),
                        "ConfigurationReference" : getCLOConfigurationReference(),
                        "RunId" : getCLORunId()
                    } +
                    attributeIfContent("CostCentre", accountObject.CostCentre!""),
                "Resources" : getOutputContent("resources"),
                "Outputs" :
                    getOutputContent("outputs") +
                    getCFTemplateCoreOutputs()
            } +
            attributeIfContent(
                "Parameters",
                getOutputContent("parameters")
            )
        ]
    [/#if]
    [#return {}]
[/#function]


[#-- Initialise the possible outputs to make sure they are available to all steps --]
[@initialiseJsonOutput name="parameters" /]
[@initialiseJsonOutput name="resources" /]
[@initialiseJsonOutput name="outputs" /]

[#assign AWS_OUTPUT_RESOURCE_TYPE = "resource" ]

[#-- Add Output Step mappings for each output --]

[@addGenerationContractStepOutputMapping
    provider=AWS_PROVIDER
    subset="template"
    outputType=AWS_OUTPUT_RESOURCE_TYPE
    outputFormat=""
    outputSuffix="template.json"
/]
