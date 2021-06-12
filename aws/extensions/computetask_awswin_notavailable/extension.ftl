[#ftl]

[@addExtension
    id="computetask_awswin_notavailable"
    aliases=[
        "_computetask_awswin_notavailable"
    ]
    description=[
       "Catch all for missing windows tasks"
    ]
    supportedTypes=[
        EC2_COMPONENT_TYPE,
        ECS_COMPONENT_TYPE,
        COMPUTECLUSTER_COMPONENT_TYPE,
        BASTION_COMPONENT_TYPE
    ]
    scopes=[
        COMPUTETASK_EXTENSION_SCOPE
    ]
/]

[#macro shared_extension_computetask_awswin_notavailable_deployment_computetask occurrence ]

    [@computeTaskConfigSection
        computeTaskTypes=[ 
            COMPUTE_TASK_EFS_MOUNT,
            COMPUTE_TASK_USER_ACCESS
        ]
        id="NotAvailable"
        priority=1
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content={}
    /]

<#-- COMPUTE_TASK_EFS_MOUNT is not supported from Windows EC2 instances -->

[/#macro]