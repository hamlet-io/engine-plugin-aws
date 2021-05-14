[#ftl]

[@addExtension
    id="computetask_linux_docker"
    aliases=[
        "_computetask_linux_docker"
    ]
    description=[
        "Installs the docker"
    ]
    supportedTypes=[
        EC2_COMPONENT_TYPE,
        COMPUTECLUSTER_COMPONENT_TYPE
    ]
    scopes=[
        COMPUTETASK_EXTENSION_SCOPE
    ]
/]

[#macro shared_extension_computetask_linux_docker_deployment_computetask occurrence ]

    [#local solution = occurrence.Configuration.Solution ]
    [#local operatingSystem = solution.ComputeInstance.OperatingSystem]

    [#local commands = {}]
    [#local content = {}]
    [#local services = {}]
    [#switch operatingSystem.Family ]
        [#case "linux" ]
            [#switch operatingSystem.Distribution ]
                [#case "awslinux" ]
                    [#local content = {
                        "packages" : {
                            "yum" : {
                                "docker" : []
                            }
                        }
                    }]
                    [#local commands += {
                        "01AddUserToDockerGroup" : {
                            "command" : "usermod -a -G docker ec2-user",
                            "ignoreErrors" : false
                        }
                    }]
                    [#break]
            [/#switch]
            [#break]
        [#break]
    [/#switch]

    [#if ! (content?has_content) ]
        [@fatal
            message="computetask_linux_docker_compose could not find a way to install the docker for this os"
            detail="Check your operating system config or replace this extension with your own"
            context={ "OccurrenceId" : core.Id, "OperatingSystem" : operatingSystem }
        /]
    [/#if]

    [#local services += {
        "sysvinit" : {
            "docker" : {
                "enabled" : true,
                "ensureRunning" : true
            }
        }
    }]

    [@computeTaskConfigSection
        computeTaskTypes=[ COMPUTE_TASK_GENERAL_TASK ]
        id="docker"
        priority=2
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content=content +
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
