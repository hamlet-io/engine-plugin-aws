[#ftl]

[@addExtension
    id="vpcendpoint_sns_access"
    aliases=[
        "_vpcendpoint_sns_access"
    ]
    description=[
        "Limits access to the sns queues"
    ]
    supportedTypes=[
        NETWORK_GATEWAY_DESTINATION_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_vpcendpoint_sns_access_deployment_setup occurrence ]

    [#local resources = [] ]
    [#list _context.Links as id, linkTarget]
        [#switch linkTarget.Core.Type]
            [#case EXTERNALSERVICE_COMPONENT_TYPE]
            [#case TOPIC_COMPONENT_TYPE]
                [#local resource = (linkTarget.State.Attributes["ARN"])!"" ]
                [#if resource?has_content]
                    [#local resources += [ resource ] ]
                [/#if]
                [#break]
        [/#switch]
    [/#list]
    [#if resources?has_content]
        [@Policy
            [
                getPolicyStatement(
                    [
                        "sns:*"
                    ],
                    resources,
                    "*",
                    {},
                    true,
                    "SNS topic access"
                )
            ]
        /]
    [/#if]
[/#macro]
