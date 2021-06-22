[#ftl]

[@addExtension
    id="computetask_awswin_ecs"
    aliases=[
        "_computetask_awswin_ecs"
    ]
    description=[
        "Setup the ecs agent and docker config for aws win instances"
    ]
    supportedTypes=[
        ECS_COMPONENT_TYPE
    ]
    scopes=[
        COMPUTETASK_EXTENSION_SCOPE
    ]
/]

[#macro shared_extension_computetask_awswin_ecs_deployment_computetask occurrence ]

    [#local solution = occurrence.Configuration.Solution]
    [#local resources = occurrence.State.Resources]

    [#local ecsId               = resources["cluster"].Id ]
    [#local dockerUsers         = solution.DockerUsers ]
    [#local dockerVolumeDrivers = solution.VolumeDrivers ]
    [#local defaultLogDriver    = solution.LogDriver ]

    [#local dockerUsersEnv = "" ]

    [#local commands = {}]
    [#local services = {}]

    [#local solution = occurrence.Configuration.Solution ]
    [#local operatingSystem = solution.ComputeInstance.OperatingSystem]

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

    [#local dockerVolumeDriverScriptName = "ecs_volume_driver_install" ]
    [#local dockerVolumeDriverScript = [] ]
    [#if dockerVolumeDrivers?has_content ]
        [#list dockerVolumeDrivers as dockerVolumeDriver ]

            [#switch dockerVolumeDriver ]
                [#case "ebs" ]
                    [#local dockerVolumeDriverScript += [
                        { "Fn::Sub" : r'docker.exe plugin install rexray/ebs REXRAY_PREEMPT=true EBS_REGION="${AWS::Region}" --grant-all-permissions' }
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
                "command" : "powershell.exe -ExecutionPolicy Bypass -Command c:\\ProgramData\\Hamlet\\Scripts\\${dockerVolumeDriverScriptName}.ps1",
                "ignoreErrors" : false
            }
        )]

    [#if dockerVolumeDriverScript?has_content ]
        [#local dockerVolumeDriverScript = [
            'Start-Transcript -Path c:\\ProgramData\\Hamlet\\Logs\\${dockerVolumeDriverScript}.log ;'
        ] + dockerVolumeDriverScript + [
            'Stop-Transcript | out-null'
        ]]
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
                r'  $ecs_log_driver=$args[0] ',
                r'  if (Test-Path $fileToCheck -PathType leaf) ',
                r'  { ',
                r'    $dockerjson = (Get-Content -Raw -Path C:\ProgramData\Docker\config\daemon.json | ConvertFrom-Json) ',
                r'    $dockerjson.log-driver = ${ecs_log_driver} ',
                r'    $dockerjson | ConvertTo-Json -depth 100 | Out-File "C:\ProgramData\Docker\config\daemon.json" ',
                r'  } else {',
                r'    echo "{ \"log-driver\":\"${ecs_log_driver}\" }" > C:\ProgramData\Docker\config\daemon.json ',
                r'  }'
                r'}',
                'update_log_driver "${defaultLogDriver}"'
            ]]
            [#break]
    [/#switch]

    [#if dockerLoggingDriverScript?has_content ]
        [#local dockerLoggingDriverScript = [
            'Start-Transcript -Path c:\\ProgramData\\Hamlet\\Logs\\${dockerLoggingDriverScript}.log ;'
        ] + dockerLoggingDriverScript  + [
            'Stop-Transcript | out-null'
        ]]
    [/#if]

    [#local commands +=
        attributeIfContent(
            "2_ConfigureDefaultLogDriver",
            dockerLoggingDriverScript,
            {
                "command" : "powershell.exe -ExecutionPolicy Bypass -Command c:\\ProgramData\\Hamlet\\Scripts\\${dockerLoggingDriverScriptName}.ps1",
                "ignoreErrors" : false
            }
        )]

    [#local services += {
        "docker" : {
            "enabled" : true,
            "ensureRunning" : true,
            "files" : [ ] +
            valueIfContent(
                [ "c:\\ProgramData\\Hamlet\\Scripts\\${dockerLoggingDriverScriptName}.ps1" ],
                dockerLoggingDriverScript,
                []
            )
        }
    }]

    [#-- Handle restart to get everything happy --]
    [#switch operatingSystem.Family ]
        [#case "windows" ]
            [#switch operatingSystem.Distribution ]
                [#case "awswin" ]
                    [#local commands += {
                        "9_RestartECSAgent" : {
                            "command" : "exit 3010",
                            "ignoreErrors" : false
                         }
                     }]
            [/#switch]
            [#break]
        [#break]
    [/#switch]


    [#local ecsCluster = getReference(ecsId) ]

    [@computeTaskConfigSection
        computeTaskTypes=[ COMPUTE_TASK_AWS_ECS_AGENT_SETUP ]
        id="ECSAgent"
        priority=5
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content={
                "files" : {
                    "c:\\ProgramData\\Amazon\\ECS\\ecs.config" : {
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
                    "c:\\ProgramData\\Hamlet\\Scripts\\${dockerVolumeDriverScriptName}.ps1",
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
                    "c:\\ProgramData\\Hamlet\\Scripts\\${dockerLoggingDriverScriptName}.ps1",
                    dockerLoggingDriverScript,
                    {
                        "content" : {
                            "Fn::Join" : [
                                "\n",
                                dockerLoggingDriverScript
                            ]
                        }
                    }
                )
            } +
            attributeIfContent(
                "users",
                userInit
            ) +
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
