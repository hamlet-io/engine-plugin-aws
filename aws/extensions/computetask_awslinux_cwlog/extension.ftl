[#ftl]

[@addExtension
    id="computetask_awslinux_cwlog"
    aliases=[
        "_computetask_awslinux_cwlog"
    ]
    description=[
        "Use the cloudwatch log agent for forwarding"
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

[#macro shared_extension_computetask_awslinux_cwlog_deployment_computetask occurrence ]

    [#local solution = occurrence.Configuration.Solution ]

    [#local logFileProfile = _context.LogFileProfile ]


    [#local solution = occurrence.Configuration.Solution ]
    [#local operatingSystem = solution.ComputeInstance.OperatingSystem]

    [#local content=[]]
    [#local awsLogsServiceName = "" ]
    [#switch operatingSystem.Family ]
        [#case "linux" ]
            [#switch operatingSystem.Distribution ]
                [#case "awslinux" ]
                    [#switch operatingSystem.MajorVersion ]
                        [#case "2023"]
                            [#local collectList = []]

                            [#list ((logFileProfile.LogFileGroups)![])?map(
                                        x -> (getReferenceData(LOGFILEGROUP_REFERENCE_TYPE)[x])!{}
                                    ) as logFileGroup ]

                                [#local logFileGroupName = _context.InstanceLogGroup ]
                                [#if logFileGroup.LogStore.Destination == "link"]
                                    [#local logFileGroupName = getLinkTarget(occurrence, logFileGroup.LogStore.Link, false).State.Resources.lg.Name ]
                                [/#if]

                                [#list logFileGroup.LogFiles?map(
                                            x -> (getReferenceData(LOGFILE_REFERENCE_TYPE)[x])!{}
                                        )?filter(
                                            x -> x?has_content) as logFileDetails ]

                                    [#local entryLines = [
                                        "          {",
                                        "            \"file_path\": \"${logFileDetails.FilePath}\",",
                                        "            \"log_group_name\": \"${logFileGroupName}\",",
                                        "            \"log_stream_name\": \"{instance_id}${logFileDetails.FilePath}\""
                                    ]]

                                    [#if (logFileDetails.TimeFormat!"")?has_content]
                                        [#local entryLines = entryLines[0..*entryLines?size-1] 
                                            + [ entryLines?last?replace("}", ",}") ]
                                        ]
                                        [#local entryLines += ["            ,\"timestamp_format\": \"${logFileDetails.TimeFormat}\""]]
                                    [/#if]

                                    [#if (logFileDetails.MultiLinePattern!"")?has_content]
                                        [#local entryLines = entryLines[0..*entryLines?size-1] 
                                            + [ entryLines?last?replace("}", ",}") ]
                                        ]
                                        [#local entryLines += ["            ,\"multi_line_start_pattern\": \"${logFileDetails.MultiLinePattern}\""]]
                                    [/#if]

                                    [#local entryLines += ["          }"]]
                                    [#local collectList += [entryLines?join("\n")]]

                                [/#list]
                            [/#list]

                            [#local logContent = [
                                "{",
                                "  \"logs\": {",
                                "    \"logs_collected\": {",
                                "      \"files\": {",
                                "        \"collect_list\": [",
                                collectList?join(",\n"),
                                "        ]",
                                "      }",
                                "    }",
                                "  }",
                                "}"
                            ]]

                            [#local content={
                                "packages" : {
                                    "yum" : {
                                        "amazon-cloudwatch-agent" : [],
                                        "jq" : []
                                    }
                                },
                                "files" : {
                                    "/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json" : {
                                        "content": {
                                            "Fn::Join": [
                                                "\n",
                                                logContent
                                            ]
                                        },
                                        "mode": "000644"
                                    },
                                    "/opt/hamlet_cfninit/awslogs.sh" : {
                                        "content": {
                                            "Fn::Join": [
                                                "\n",
                                                [
                                                "#!/bin/bash",
                                                "set -euo pipefail",
                                                "TOKEN=$(curl -s -X PUT \"http://169.254.169.254/latest/api/token\" -H \"X-aws-ec2-metadata-token-ttl-seconds: 21600\")",
                                                "IMDS() { curl -s -H \"X-aws-ec2-metadata-token: $TOKEN\" \"http://169.254.169.254/latest/meta-data/$1\"; }",
                                                "instance_id=$(IMDS instance-id)",
                                                "sed -i -e \"s/{instance_id}/$instance_id/g\" /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json",
                                                "/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"
                                                ]
                                            ]
                                        },
                                        "mode": "000755"
                                    }
                                },
                                "commands": {
                                    "ConfigureLogsAgent" : {
                                        "command" : "/opt/hamlet_cfninit/awslogs.sh",
                                        "ignoreErrors" : false
                                    }
                                }
                            }]
                            [#break]
                        [#case "2"]
                        [#case "1" ]
                            [#if operatingSystem.MajorVersion == "2"]
                                [#local awsLogsServiceName = "awslogsd"]
                            [#else]
                                [#local awsLogsServiceName = "awslogs"]
                            [/#if]


                            [#local logContent = [
                                "[general]",
                                "state_file = /var/lib/awslogs/agent-state",
                                ""
                            ]]

                            [#list ((logFileProfile.LogFileGroups)![])?map(
                                        x -> (getReferenceData(LOGFILEGROUP_REFERENCE_TYPE)[x])!{}
                                    ) as logFileGroup ]

                                [#local logFileGroupName = _context.InstanceLogGroup ]
                                [#if logFileGroup.LogStore.Destination == "link"]
                                    [#local logFileGroupName = getLinkTarget(occurrence, logFileGroup.LogStore.Link, false).State.Resources.lg.Name ]
                                [/#if]

                                [#list logFileGroup.LogFiles?map(
                                            x -> (getReferenceData(LOGFILE_REFERENCE_TYPE)[x])!{}
                                        )?filter(
                                            x -> x?has_content) as logFileDetails ]

                                    [#local logContent +=
                                        [
                                            "[${logFileDetails.FilePath}]",
                                            "file = ${logFileDetails.FilePath}",
                                            "log_group_name = ${logFileGroupName}",
                                            "log_stream_name = {instance_id}${logFileDetails.FilePath}"
                                        ] +
                                        (logFileDetails.TimeFormat!"")?has_content?then(
                                            [ "datetime_format = ${logFileDetails.TimeFormat}"],
                                            []
                                        ) +
                                        (logFileDetails.MultiLinePattern!"")?has_content?then(
                                            [ "awslogs-multiline-pattern = ${logFileDetails.MultiLinePattern}" ],
                                            []
                                        ) +
                                        [ "" ]
                                    ]
                                [/#list]
                            [/#list]

                            [#local content={
                                "packages" : {
                                    "yum" : {
                                        "awslogs" : [],
                                        "jq" : []
                                    }
                                },
                                "files" : {
                                    "/etc/awslogs/awscli.conf" : {
                                        "content" : {
                                            "Fn::Join" : [
                                                "\n",
                                                [
                                                    "[plugins]",
                                                    "cwlogs = cwlogs",
                                                    "[default]",
                                                    { "Fn::Sub" : r'region = ${AWS::Region}' }
                                                ]
                                            ]
                                        },
                                        "mode" : "000644"
                                    },
                                    "/etc/awslogs/awslogs.conf" : {
                                        "content" : {
                                            "Fn::Join" : [
                                                "\n",
                                                logContent
                                            ]
                                        },
                                        "mode" : "000644"
                                    },
                                    "/opt/hamlet_cfninit/awslogs.sh" : {
                                        "content" : {
                                            "Fn::Join" : [
                                                "\n",
                                                [
                                                    r'#!/bin/bash',
                                                    r'# Metadata log details',
                                                    r"ecs_cluster=$(curl -s http://localhost:51678/v1/metadata | jq -r '. | .Cluster')",
                                                    r"ecs_container_instance_id=$(curl -s http://localhost:51678/v1/metadata | jq -r '. | .ContainerInstanceArn' | awk -F/ '{print $2}' )",
                                                    r'macs=$(curl http://169.254.169.254/latest/meta-data/network/interfaces/macs/ | head -1 )',
                                                    r'vpc_id=$(curl http://169.254.169.254/latest/meta-data/network/interfaces/macs/$macs/vpc-id )',
                                                    r'instance_id=$(curl http://169.254.169.254/latest/meta-data/instance-id)',
                                                    r'',
                                                    r'sed -i -e "s/{instance_id}/$instance_id/g" /etc/awslogs/awslogs.conf',
                                                    r'sed -i -e "s/{ecs_container_instance_id}/$ecs_container_instance_id/g" /etc/awslogs/awslogs.conf',
                                                    r'sed -i -e "s/{ecs_cluster}/$ecs_cluster/g" /etc/awslogs/awslogs.conf',
                                                    r'sed -i -e "s/{vpc_id}/$vpc_id/g" /etc/awslogs/awslogs.conf'
                                                ]
                                            ]
                                        },
                                        "mode" : "000755"
                                    }
                                },
                                "services" : {
                                    "sysvinit" : {
                                        awsLogsServiceName : {
                                            "ensureRunning" : true,
                                            "enabled" : true,
                                            "files" : [
                                                "/etc/awslogs/awslogs.conf",
                                                "/etc/awslogs/awscli.conf"
                                            ],
                                            "packages" : [ "awslogs" ],
                                            "commands" : [ "ConfigureLogsAgent" ]
                                        }
                                    }
                                },
                                "commands": {
                                    "ConfigureLogsAgent" : {
                                        "command" : "/opt/hamlet_cfninit/awslogs.sh",
                                        "ignoreErrors" : false
                                    }
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
        computeTaskTypes=[ COMPUTE_TASK_SYSTEM_LOG_FORWARDING ]
        id="CloudWatchLogs"
        priority=2
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content=content
    /]

[/#macro]
