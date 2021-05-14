[#ftl]

[@addExtension
    id="computetask_linux_docker_compose"
    aliases=[
        "_computetask_linux_docker_compose"
    ]
    description=[
        "Installs the docker compose"
    ]
    supportedTypes=[
        EC2_COMPONENT_TYPE,
        COMPUTECLUSTER_COMPONENT_TYPE
    ]
    scopes=[
        COMPUTETASK_EXTENSION_SCOPE
    ]
/]

[#macro shared_extension_computetask_linux_docker_compose_deployment_computetask occurrence ]

    [#local version = "1.29.1"]

    [#local commands = {}]
    [#local commands += {
        "01DownloadDockerCompose" : {
            "command" : "curl -L \"https://github.com/docker/compose/releases/download/${version}/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose",
            "ignoreErrors" : false
        },
        "02ApplyExecutablePermission" : {
            "command" : "chmod +x /usr/local/bin/docker-compose",
            "ignoreErrors" : false
        },
        "04TestInstallation" : {
            "command" : "docker-compose --version",
            "ignoreErrors" : false
        }
    }]

    [@computeTaskConfigSection
        computeTaskTypes=[ COMPUTE_TASK_GENERAL_TASK ]
        id="docker-compose"
        priority=3
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content= {} +
            attributeIfContent(
                "commands",
                commands
            )
    /]

[/#macro]
