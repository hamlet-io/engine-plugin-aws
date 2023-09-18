[#ftl]

[@addExtension
    id="vpcendpoint_source_access"
    aliases=[
        "_vpcendpoint_source_access"
    ]
    description=[
        "Limits access FROM a set of vpc endpoints"
    ]
    supportedTypes=["*"]
/]

[#macro shared_extension_vpcendpoint_source_access_deployment_setup occurrence ]

    [#local resources = [] ]
    [#list _context.Links as id, linkTarget]
        [#switch linkTarget.Core.Type]
            [#case EXTERNALSERVICE_COMPONENT_TYPE]
            [#case NETWORK_GATEWAY_DESTINATION_COMPONENT_TYPE]
                [#local endpoints = (linkTarget.State.Attributes["VPC_ENDPOINTS"])!""]
                [#if endpoints?has_content]
                    [#local resources = getUniqueArrayElements(resources, endpoints?split(",")) ]
                [/#if]
                [#break]
        [/#switch]
    [/#list]
    [#if resources?has_content]
        [@Policy
            [
                getPolicyStatement(
                    "*",
                    "*",
                    "",
                    getVPCEndpointCondition(resources, false),
                    false,
                    "Limit access to specific vpc endpoints"
                )
            ]
        /]
    [/#if]
[/#macro]
