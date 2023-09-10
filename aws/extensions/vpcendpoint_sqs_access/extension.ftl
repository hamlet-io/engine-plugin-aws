[#ftl]

[@addExtension
    id="vpcendpoint_sqs_access"
    aliases=[
        "_vpcendpoint_sqs_access"
    ]
    description=[
        "Limits access to the sqs queues"
    ]
    supportedTypes=[
        NETWORK_GATEWAY_DESTINATION_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_vpcendpoint_sqs_access_deployment_setup occurrence ]

    [#local resources = [] ]
    [#list _context.Links as id, linkTarget]
        [#switch linkTarget.Core.Type]
            [#case EXTERNALSERVICE_COMPONENT_TYPE]
            [#case SQS_COMPONENT_TYPE]
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
                        "sqs:*"
                    ],
                    resources,
                    "*",
                    {},
                    true,
                    "SQS queue access"
                )
            ]
        /]
    [/#if]
[/#macro]
