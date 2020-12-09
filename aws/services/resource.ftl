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
                getExistingReference(AWS_PROVIDER, idOrArn, ARN_ATTRIBUTE_TYPE, inRegion),
                existingOnly,
                getReference(AWS_PROVIDER, idOrArn, ARN_ATTRIBUTE_TYPE, inRegion)
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

[#-- Metric Dimensions are extended dynamically by each resouce type --]
[#assign metricAttributes = {
    "_none" : {
        "Namespace" : "",
        "Dimensions" : {
            "None" : {
                "None" : ""
            }
        }
    }
}]

[#-- Include a reference to a resource --]
[#-- Allows resources to share a template or be separated --]
[#-- Note that if separate, creation order becomes important --]
[#function migrateToResourceId resourceId legacyIds=[] inRegion="" inDeploymentUnit="" inAccount=(accountObject.AWSId)!""]

    [#list asArray(legacyIds) as legacyId]
        [#if getExistingReference(AWS_PROVIDER, legacyId, "", inRegion, inDeploymentUnit, inAccount)?has_content]
            [#return legacyId]
        [/#if]
    [/#list]
    [#return resourceId]
[/#function]

[#-- Called from shared/services/resource.ftl:getReference when not in current scope --]
[#function aws_getReference resourceId attributeType="" inRegion="" optParams={}]
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
            AWS_PROVIDER,
            resourceId,
            attributeType,
            inRegion)
    ]
[/#function]

[#function getReferences resourceIds attributeType="" inRegion=""]
    [#local result = [] ]
    [#list asArray(resourceIds) as resourceId]
        [#local result += [getReference(AWS_PROVIDER, resourceId, attributeType, inRegion)] ]
    [/#list]
    [#return result]
[/#function]
