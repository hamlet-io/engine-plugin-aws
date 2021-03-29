[#ftl]

[#-- Format an ARN --]
[#function formatTypedArnResource resourceType resource resourceSeparator=":" subresources=[] ]
    [#return
        {
            "Fn::Join": [
                resourceSeparator,
                [
                    resourceType,
                    resource
                ] +
                subresources
            ]
        }
    ]
    [#return resourceType + resourceSeparator + resource]
[/#function]

[#function formatArn partition service region account resource asString=false]
    [#if asString ]
        [#return
            [
                "arn",
                partition,
                service,
                region,
                account,
                resource
            ]?join(":")
        ]
    [#else]
        [#return
            {
                "Fn::Join": [
                    ":",
                    [
                        "arn",
                        partition,
                        service,
                        region,
                        account,
                        resource
                    ]
                ]
            }
        ]
    [/#if]
[/#function]

[#function getArn idOrArn existingOnly=false inRegion=""]
    [#if idOrArn?is_hash || idOrArn?contains(":")]
        [#return idOrArn]
    [#else]
        [#return
            valueIfTrue(
                getExistingReference(idOrArn, ARN_ATTRIBUTE_TYPE, inRegion),
                existingOnly,
                getReference(idOrArn, ARN_ATTRIBUTE_TYPE, inRegion)
            ) ]
    [/#if]
[/#function]

[#function formatRegionalArn service resource region={ "Ref" : "AWS::Region" } account={ "Ref" : "AWS::AccountId" }]
    [#return
        formatArn(
            { "Ref" : "AWS::Partition" },
            service,
            region,
            account,
            resource
        )
    ]
[/#function]

[#function formatGlobalArn service resource account={ "Ref" : "AWS::AccountId" }]
    [#return
        formatRegionalArn(
            service,
            resource,
            "",
            account
        )
    ]
[/#function]

[#-- *** CloudWatch Metric Management *** --]

[#-- Metric Dimensions are extended dynamically by each resouce type --]
[#assign CWMetricAttributes = {}]

[#macro addCWMetricAttributes resourceType namespace dimensions ]
    [#assign CWMetricAttributes = mergeObjects(
            CWMetricAttributes,
            {
                resourceType : {
                    "Namespace" : namespace,
                    "Dimensions" : dimensions
                }
            }
    )]
[/#macro]

[#-- Add dummy attribute --]
[@addCWMetricAttributes
    resourceType="_none"
    namespace=""
    dimensions={
        "None" : {
            "None" : ""
        }
    }
/]

[#function getCWMetricDimensions alert monitoredResource resources environment={}]
    [#switch alert.DimensionSource]
        [#case "Resource" ]
            [#return getCWResourceMetricDimensions(monitoredResource, resources)]
            [#break]

        [#case "Configured" ]
            [#local dimensions = [] ]
            [#list alert.Dimensions as id, dimension ]
                [#local value = ""]
                [#if ((dimension.SettingEnvName)!"")?has_content ]
                    [#local value = (environment["Environment"][dimension.SettingEnvName])!"" ]
                [#else]
                    [#local value = (dimension.Value)!"" ]
                [/#if]

                [#local dimensions += [ {
                    "Name" : dimension.Key,
                    "Value" : value
                }]]
            [/#list]
            [#return dimensions]
            [#break]
    [/#switch]

    [#return []]
[/#function]

[#function getCWResourceMetricDimensions resource resources]
    [#local resourceMetricAttributes = CWMetricAttributes[resource.Type]!{} ]

    [#if resourceMetricAttributes?has_content ]
        [#local occurrenceDimensions = [] ]
        [#list resourceMetricAttributes.Dimensions as name,property ]
            [#list property as key,value ]
                [#switch key]
                    [#case "ResourceProperty" ]
                        [#local occurrenceDimensions += [{
                            "Name" : name,
                            "Value" : resource[value]
                        }]]
                        [#break]
                    [#case "OtherResourceProperty" ]
                        [#local otherResource = getResourceFromId(resources, value.Id)]
                        [#local occurrenceDimensions += [{
                            "Name" : name,
                            "Value" : otherResource[value.Property]
                        }]]
                        [#break]
                    [#case "Output" ]
                        [#if (value.MustExist)!false ]
                            [#local occurrenceDimensions += [{
                                "Name" : name,
                                "Value" : getExistingReference(resource.Id, value.Attribute)
                            }]]
                        [#else]
                            [#local occurrenceDimensions += [{
                                "Name" : name,
                                "Value" : getReference(resource.Id, value.Attribute)
                            }]]
                        [/#if]
                        [#break]
                    [#case "OtherOutput" ]
                        [#local otherResource = getResourceFromId(resources, value.Id)]
                        [#if (value.MustExist)!false ]
                            [#local occurrenceDimensions += [{
                                "Name" : name,
                                "Value" : getExistingReference(otherResource.Id, value.Property)
                            }]]
                        [#else]
                            [#local occurrenceDimensions += [{
                                "Name" : name,
                                "Value" : getReference(otherResource.Id, value.Property)
                            }]]
                        [/#if]
                        [#break]
                    [#case "PseudoOutput" ]
                        [#local occurrenceDimensions += [{
                            "Name" : name,
                            "Value" : { "Ref" : value }
                        }]]
                        [#break]
                [/#switch]
            [/#list]
        [/#list]

        [#return occurrenceDimensions]
    [#else]
        [@fatal
            message="Dimensions not mapped for this resource"
            context=resource.Type
        /]
    [/#if]

[/#function]

[#function getCWResourceMetricNamespace resourceType override="" ]

    [#if override?has_content ]
        [#return override]
    [/#if]

    [#local resourceTypeNameSpace = (CWMetricAttributes[resourceType]).Namespace!"" ]

    [#if resourceTypeNameSpace?has_content ]
        [#switch resourceTypeNameSpace ]
            [#case "_productPath" ]
                [#return formatProductRelativePath()]
                [#break]

            [#default]
                [#return resourceTypeNameSpace]
        [/#switch]
    [#else]
        [@fatal
            message="Namespace not mapped for this resource"
            context=resource.Type
        /]
    [/#if]
[/#function]

[#function getCWMetricName metricName resourceType shortFullName ]

    [#-- For some metrics we need to append the resourceName to add a qualifier if they don't support dimensions --]
    [#switch resourceType]
        [#case AWS_CLOUDWATCH_LOG_METRIC_RESOURCE_TYPE ]
            [#return formatName(metricName, shortFullName) ]
    [#break]

    [#default]
        [#return metricName]
    [/#switch]
[/#function]

[#function getCWMonitoredResources coreId resources resourceQualifier ]
    [#local monitoredResources = {} ]

    [#-- allow for a none type which disables dimension lookup --]
    [#if resourceQualifier.Type?has_content && resourceQualifier.Type == "_none" ]
        [#return { "_none" : { "Id" : coreId, "Type" : "_none" } }]
    [/#if]

    [#list resources as id,resource ]

        [#if !resource["Type"]?has_content && resource?is_hash]
            [#list resource as id,subResource ]
                [#local monitoredResources += getCWMonitoredResources(coreId, {id : subResource}, resourceQualifier)]
            [/#list]

        [#else]

            [#if resourceQualifier.Id?has_content || resourceQualifier.Type?has_content ]

                [#if resourceQualifier.Id?has_content && resourceQualifier.Id == id  ]
                    [#local monitoredResources += {
                        id: resource
                    }]
                [/#if]

                [#if resourceQualifier.Type?has_content && resourceQualifier.Type == resource["Type"]  ]
                    [#local monitoredResources += {
                        id: resource
                    }]
                [/#if]

            [#else]

                [#if resource["Type"]?has_content]

                    [#if resource["Monitored"]!false ]
                        [#local monitoredResources += {
                            id : resource
                        }]
                    [/#if]
                [/#if]

            [/#if]
        [/#if]
    [/#list]
    [#return monitoredResources ]
[/#function]

[#-- Include a reference to a resource --]
[#-- Allows resources to share a template or be separated --]
[#-- Note that if separate, creation order becomes important --]
[#function getExistingReference resourceId attributeType="" inRegion="" inDeploymentUnit="" inAccount=(accountObject.ProviderId)!""]
    [#local attributeType = (attributeType == REFERENCE_ATTRIBUTE_TYPE)?then(
                                "",
                                attributeType
    )]
    [#return getStatePointValue( formatAttributeId(resourceId, attributeType), inDeploymentUnit, inAccount, inRegion) ]
[/#function]

[#function migrateToResourceId resourceId legacyIds=[] inRegion="" inDeploymentUnit="" inAccount=(accountObject.ProviderId)!""]

    [#list asArray(legacyIds) as legacyId]
        [#if getExistingReference(legacyId, "", inRegion, inDeploymentUnit, inAccount)?has_content]
            [#return legacyId]
        [/#if]
    [/#list]
    [#return resourceId]
[/#function]

[#function getReference resourceId attributeType="" inRegion=""]
    [#if !(resourceId?has_content)]
        [#return ""]
    [/#if]
    [#if resourceId?is_hash]
        [#return
            {
                "Ref" : value.Ref
            }
        ]
    [/#if]
    [#if ((!(inRegion?has_content)) || (inRegion == region)) &&
        isPartOfCurrentDeploymentUnit(resourceId)]
        [#if attributeType?has_content]
            [#local resourceType = getResourceType(resourceId) ]
            [#local mapping = getOutputMappings(AWS_PROVIDER, resourceType, attributeType)]
            [#if (mapping.Attribute)?has_content]
                [#return
                    {
                        "Fn::GetAtt" : [resourceId, mapping.Attribute]
                    }
                ]
            [#elseif !(mapping.UseRef)!false ]
                [#return
                    {
                        "Mapping" : "HamletFatal: Unknown Resource Type",
                        "ResourceId" : resourceId,
                        "ResourceType" : resourceType
                    }
                ]
            [/#if]
        [/#if]
        [#return
            {
                "Ref" : resourceId
            }
        ]
    [/#if]
    [#return
        getExistingReference(
            resourceId,
            attributeType,
            inRegion)
    ]
[/#function]

[#function getReferences resourceIds attributeType="" inRegion=""]
    [#local result = [] ]
    [#list asArray(resourceIds) as resourceId]
        [#local result += [getReference(resourceId, attributeType, inRegion)] ]
    [/#list]
    [#return result]
[/#function]
