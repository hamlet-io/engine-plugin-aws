[#ftl]

[@addExtension
    id="computetask_awslinux_ecs"
    aliases=[
        "_computetask_awslinux_ecs"
    ]
    description=[
        "Setup the ecs agent and docker config for aws linux instances"
    ]
    supportedTypes=[
        ECS_COMPONENT_TYPE
    ]
    scopes=[
        COMPUTETASK_EXTENSION_SCOPE
    ]
/]

[#macro shared_extension_computetask_awslinux_ecs_deployment_computetask occurrence ]

    [#local solution = occurrence.Configuration.Solution]
    [#local resources = occurrence.State.Resources]

    [#local ecsId               = resources["cluster"].Id ]
    [#local dockerUsers         = solution.DockerUsers ]
    [#local dockerVolumeDrivers = solution.VolumeDrivers ]
    [#local defaultLogDriver    = solution.LogDriver ]

    [#local dockerUsersEnv = "" ]

    [#local userInit = {}]
    [#if dockerUsers?has_content ]
        [#list dockerUsers as userName,details ]

            [#local userInit = mergeObjects(
                                userInit,
                                {
                                    userName : {
                                        "groups" : [ "docker" ],
                                        "uid" : details.UID
                                    }
                                })]
        [/#list]
    [/#if]

    [#local commands = {}]

    [#local commands +=
        {
            "9_RestartECSAgent" : {
                "command" : "stop ecs; start ecs",
                "ignoreErrors" : false
            }
        }
    ]

    [#local dockerVolumeDriverScriptName = "ecs_volume_driver_install" ]
    [#local dockerVolumeDriverScript = [] ]
    [#if dockerVolumeDrivers?has_content ]
        [#list dockerVolumeDrivers as dockerVolumeDriver ]

            [#switch dockerVolumeDriver ]
                [#case "ebs" ]

                    [#local dockerVolumeDriverScript += [
                        { "Fn::Sub" : r'docker plugin install rexray/ebs REXRAY_PREEMPT=true EBS_REGION="${AWS::Region}" --grant-all-permissions' }
                    ]]
                    [#break]
            [/#switch]
        [/#list]
    [/#if]

    [#local commands +=
        attributeIfContent(
            "1_InstallVolumeDrivers",
            dockerVolumeDriverScript,
            {
                "command" : "/opt/hamlet_cfninit/${dockerVolumeDriverScriptName}.sh",
                "ignoreErrors" : false
            }
        )]

    [#if dockerVolumeDriverScript?has_content ]
        [#local dockerVolumeDriverScript = [
            r'#!/bin/bash',
            r'set -euo pipefail',
            'exec > >(tee /var/log/hamlet_cfninit/${dockerVolumeDriverScriptName}.log | logger -t ${dockerVolumeDriverScriptName} -s 2>/dev/console) 2>&1'
        ] + dockerVolumeDriverScript ]
    [/#if]

    [#local dockerLoggingDriverScriptName = "ecs_log_driver_config" ]
    [#local dockerLoggingDriverScript = []]
    [#switch defaultLogDriver ]
        [#case "awslogs"]
            [#break]

        [#case "json-file"]
        [#case "fluentd" ]
            [#local dockerLoggingDriverScript += [
                r'function update_log_driver {',
                r'  local ecs_log_driver="$1"; shift',
                r'  . /etc/sysconfig/docker',
                r'  if [[ -n "${OPTIONS}" ]]; then',
                r'     sed -i "s,^\(OPTIONS=\).*,\1\"${OPTIONS} --log-driver=${ecs_log_driver}\",g" /etc/sysconfig/docker',
                r'  else',
                r'     echo "OPTIONS=\"--log-driver=${ecs_log_driver}\"" >> /etc/sysconfig/docker',
                r'    fi'
                r'}',
                'update_log_driver "${defaultLogDriver}"'
            ]]
            [#break]
    [/#switch]

    [#if dockerLoggingDriverScript?has_content ]
        [#local dockerVolumeDriverScript = [
            r'#!/bin/bash',
            r'set -euo pipefail',
            'exec > >(tee /var/log/hamlet_cfninit/${dockerLoggingDriverScriptName}.log | logger -t ${dockerLoggingDriverScriptName} -s 2>/dev/console) 2>&1'
        ] + dockerLoggingDriverScript ]
    [/#if]

    [#local commands +=
        attributeIfContent(
            "2_ConfigureDefaultLogDriver",
            dockerLoggingDriverScript,
            {
                "command" : "/opt/hamlet_cfninit/${dockerLoggingDriverScriptName}.sh",
                "ignoreErrors" : false
            }
        )]

    [#local ecsCluster = valueIfContent(
                            getExistingReference(ecsId),
                            getExistingReference(ecsId),
                            getReference(ecsId)
                    )]

    [@computeTaskConfigSection
        computeTaskTypes=[ COMPUTE_TASK_AWS_ECS_AGENT_SETUP ]
        id="ECSAgent"
        priority=5
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content={
                "files" : {
                    "/etc/ecs/ecs.config" : {
                        "content" : {
                            "Fn::Join" : [
                                "\n",
                                [
                                    {
                                        "Fn::Sub" : [
                                            r'ECS_CLUSTER=${clusterId}',
                                            { "clusterId": ecsCluster }
                                        ]
                                    }
                                    r'ECS_LOGLEVEL=warn',
                                    r'ECS_ENGINE_TASK_CLEANUP_WAIT_DURATION=10m',
                                    r'ECS_AVAILABLE_LOGGING_DRIVERS=["awslogs","fluentd","gelf","json-file","journald","syslog"]'
                                ]
                            ]
                        },
                        "mode" : "000644"
                    }
                } +
                attributeIfContent(
                    "/opt/hamlet_cfninit/${dockerVolumeDriverScriptName}.sh",
                    dockerVolumeDriverScript,
                    {
                        "content" : {
                            "Fn::Join" : [
                                "\n",
                                dockerVolumeDriverScript
                            ]
                        },
                        "mode" : "000755"
                    }
                ) +
                attributeIfContent(
                    "/opt/hamlet_cfninit/${dockerLoggingDriverScriptName}.sh",
                    dockerLoggingDriverScript,
                    {
                        "content" : {
                            "Fn::Join" : [
                                "\n",
                                dockerLoggingDriverScript
                            ]
                        }
                    }
                ),
                "services" : {
                    "sysvinit" : {
                        "docker" : {
                            "enabled" : true,
                            "ensureRunning" : true,
                            "files" : [ ] +
                            valueIfContent(
                                [ "/opt/hamlet_cfninit/${dockerLoggingDriverScriptName}.sh" ],
                                dockerLoggingDriverScript,
                                []
                            )
                        }
                    }
                }
            } +
            attributeIfContent(
                "users",
                userInit
            ) +
            attributeIfContent(
                "commands",
                commands
            )
    /]
[/#macro]
