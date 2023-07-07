[#ftl]

[@addExtension
    id="vpcendpoint_apigateway_access"
    aliases=[
        "_vpcendpoint_apigateway_access"
    ]
    description=[
        "Limits access to the linked apis"
    ]
    supportedTypes=[
        NETWORK_GATEWAY_DESTINATION_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_vpcendpoint_apigateway_access_deployment_setup occurrence ]

    [#local resources = [] ]
    [#list _context.Links as id, linkTarget]
        [#local resource = (linkTarget.State.Attributes["ARN"])!"" ]
        [#if resource?has_content]
            [#local resources += [ resource?ensure_ends_with("/*") ] ]
        [/#if]
    [/#list]
    [#if resources?has_content]
        [@Policy
            [
                getPolicyStatement(
                    [
                        "execute-api:Invoke"
                    ],
                    resources,
                    "*",
                    {},
                    true,
                    "Private API Gateway access"
                )
            ]
        /]
    [/#if]
[/#macro]
