[#ftl]

[@addExtension
    id="user_ses_smtp_permissions"
    aliases=[
        "_user_ses_smtp_permissions"
    ]
    description=[
        "Provide a user with the permissions to send emails using SMTP"
    ]
    supportedTypes=[
        USER_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_runbook_user_ses_smtp_permissions_runbook_setup occurrence ]

    [@includeServicesConfiguration
        provider=AWS_PROVIDER
        services=AWS_SIMPLE_EMAIL_SERVICE
        deploymentFramework=CLOUD_FORMATION_DEPLOYMENT_FRAMEWORK
    /]

    [@Policy getSESSendStatement() /]
[/#macro]
