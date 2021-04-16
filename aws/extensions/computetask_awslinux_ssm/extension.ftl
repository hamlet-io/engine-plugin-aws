[#ftl]

[@addExtension
    id="computetask_awslinux_ssm"
    aliases=[
        "_computetask_awslinux_ssm"
    ]
    description=[
        "Install and enable the System Set Manager agent"
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

[#macro shared_extension_computetask_awslinux_ssm_deployment_computetask occurrence ]

    [#local commands = {}]
    [#local services = {}]

    [#local solution = occurrence.Configuration.Solution ]
    [#local operatingSystem = solution.ComputeInstance.OperatingSystem]

    [#switch operatingSystem.Family ]
        [#case "linux" ]
            [#switch operatingSystem.Distribution ]
                [#case "awslinux" ]
                    [#switch operatingSystem.MajorVersion ]
                        [#case "2"]
                            [#local services += {
                                "sysvinit" : {
                                    "amazon-ssm-agent" : {
                                        "ensureRunning" : true,
                                        "enabled" : true,
                                        "packages" : { "yum" : [ "amazon-ssm-agent" ]}
                                    }
                                }
                            }]
                            [#break]
                        [#case "1" ]

                            [#local commands += {
                                "StartSSMAgent" : {
                                    "command" : "start amazon-ssm-agent || status amazon-ssm-agent",
                                    "ignoreErrors" : false
                                }
                            }]
                            [#break]
                    [/#switch]
                    [#break]
            [/#switch]
            [#break]
        [#break]
    [/#switch]

    [@computeTaskConfigSection
        computeTaskTypes=[ COMPUTE_TASK_GENERAL_TASK ]
        id="SSMAgent"
        priority=1
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content={
            "packages" : {
                "yum" : {
                    "amazon-ssm-agent" : []
                }
            }
        } +
        attributeIfContent(
            "commands",
            commands
        ) +
        attributeIfContent(
            "services",
            services
        )
    /]

[/#macro]
