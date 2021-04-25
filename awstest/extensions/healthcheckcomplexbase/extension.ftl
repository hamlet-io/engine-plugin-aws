[#ftl]

[@addExtension
    id="healthcheckcomplexbase"
    aliases=[
        "_healthcheckcomplexbase"
    ]
    description=[
        "Base script content for healthcheck"
    ]
    supportedTypes=[
        HEALTHCHECK_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_healthcheckcomplexbase_deployment_setup occurrence ]

    [@Settings
        "LB_FQDN"
    /]

    [@HealthCheckScript
        content=[
            r'def basic_custom_script():',
            r'    fail = False',
            r'    if fail:',
            r'        raise Exception("Failed basicCanary check.")',
            r'    return "Successfully completed basicCanary checks."',
            r'def handler(event, context):',
            r'    return basic_custom_script()'
        ]
    /]

[/#macro]
