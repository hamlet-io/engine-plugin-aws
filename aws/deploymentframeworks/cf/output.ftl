[#ftl]

[#-- Availability Zone Params --]
[#-- Uses parameters to define AZ's inline with cfnlint best practice --]
[#assign AWS_AZ_PARAMETER_TYPE = "AvailabilityZoneParam"]

[#macro addCFTemplateAzParams zoneIds ]
    [#list asArray(zoneIds) as zoneId ]
        [#list getZones() as zone ]
            [#if zoneId == zone.Id ]
                [@cfParameter
                    id=formatAWSAzParameterId(zoneId)
                    type="AWS::EC2::AvailabilityZone::Name"
                    default=zone.AWSZone
                /]
            [/#if]
        [/#list]
    [/#list]
[/#macro]

[#function formatAWSAzParameterId zoneId ]
    [#return formatResourceId(AWS_AZ_PARAMETER_TYPE, zoneId)]
[/#function]

[#function getCFAWSAzReference zoneId ]
    [@addCFTemplateAzParams zoneIds=[zoneId] /]
    [#return { "Ref" : formatAWSAzParameterId(zoneId) }]
[/#function]

[#function getCFAWSAzReferences zoneIds]
    [#local result = []]
    [#list zoneIds as zoneId]
        [#local result += [ getCFAWSAzReference(zoneId) ]]
    [/#list]
    [#return result]
[/#function]

[#-- Template outputs --]
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

[#function getCfTemplateDefaultOutputs]
    [#return
        {
            REFERENCE_ATTRIBUTE_TYPE : {
                "UseRef" : true
            }
        }
    ]
[/#function]

[#function getCFResourceTags tags={} flatten=false maxTagCount=50]

    [#local maxTagCount = ( maxTagCount -1 lt tags?keys?size )?then(
                                maxTagCount,
                                tags?keys?size
    )]

    [#if flatten ]

        [#local tags=tags?keys[0..( maxTagCount -1 )]?map(x -> { x: tags[x]})]

        [#local result = {}]
        [#list tags as tag]
            [#local result = mergeObjects(result, tag)]
        [/#list]

    [#else]
        [#local result = tags?keys?map(
            x -> {"Key": x, "Value": tags[x] }
        )]

        [#local result = result[0..( maxTagCount -1 )]]
    [/#if]
    [#return result]
[/#function]

[#-- Template Components --]
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
            tags={}
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
                        properties + attributeIfContent(
                            "Tags",
                            tags?is_sequence?then(tags, getCFResourceTags(tags))
                        )
                    ) +
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
                    content?eval_json,
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
            noEcho=false
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
                ) +
                attributeIfTrue(
                    "NoEcho",
                    noEcho,
                    "true"
                )
            }
    /]
[/#macro]


[#function cf_output_resource level="" include=""]

    [@setOutputProperties
        properties={ "type:file" : { "format" : "json" }}
    /]

    [#-- Resources --]
    [#if include?has_content]
        [#if include?contains("[#ftl]") ]
            [#-- treat as interpretable content --]
            [#local inlineInclude = include?interpret]
            [@inlineInclude /]
        [#else]
            [#-- assume a filename --]
            [#include include?ensure_starts_with("/") ]
        [/#if]
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
