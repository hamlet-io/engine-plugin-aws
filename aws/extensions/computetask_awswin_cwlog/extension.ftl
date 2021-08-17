[#ftl]

[@addExtension
    id="computetask_awswin_cwlog"
    aliases=[
        "_computetask_awswin_cwlog"
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

[#macro shared_extension_computetask_awswin_cwlog_deployment_computetask occurrence ]

    [#local solution = occurrence.Configuration.Solution ]

    [#local agentConfig = {}]

    [#local logFileProfile = _context.LogFileProfile ]
    [#local logGroupName = _context.InstanceLogGroup ]

    [#local solution = occurrence.Configuration.Solution ]
    [#local operatingSystem = solution.ComputeInstance.OperatingSystem]

    [#-- Configure the user defined log file collection and forwarding to CloudWatch --]
    [#local logFileConfigs = [
        {
            "file_path" : r'C:\ProgramData\Hamlet\Logs\user-data.log',
            "log_group_name" : logGroupName,
            "log_stream_name" : "{instance_id}/user-data"
        },
        {
            "file_path" : r'C:\ProgramData\Hamlet\Logs\user-step.log',
            "log_group_name" : logGroupName,
            "log_stream_name" : "{instance_id}/user-step"
        }
    ]]

    [#list logFileProfile.LogFileGroups as logFileGroup ]
        [#local logGroup = logFileGroups[logFileGroup] ]
        [#list logGroup.LogFiles as logFile ]
            [#local logFileDetails = logFiles[logFile] ]
            [#local timeFormat = logFileDetails.TimeFormat]
            [#local timeFormat = timeFormat!'%Y/%m/%d %H:%M:%S%Z']

            [#local logStreamName = logFileDetails.FilePath?replace(":", "")?replace(r'\', '/')?replace(r'\p{Space}', '', 'r') ]

            [#local logFileConfigs += [ {
                "file_path" : logFileDetails.FilePath,
                "log_group_name" : logGroupName,
                "log_stream_name" : "{instance_id}/${logStreamName}",
                "timestamp_format" : timeFormat
            }]]

        [/#list]
    [/#list]

    [#-- Collect Windows Event Logs and forward them to CW Logs --]
    [#-- Currently just collect the standard event logs --]
    [#local windowsEventLogs = [
        {
            "event_format" : "xml",
            "event_levels" : [
                "INFORMATION",
                "WARNING",
                "ERROR",
                "CRITICAL"
            ],
            "event_name" : "System",
            "log_group_name" : logGroupName,
            "log_stream_name" : "{instance_id}/System"
        },
        {
            "event_format" : "xml",
            "event_levels" : [
                "INFORMATION",
                "WARNING",
                "ERROR",
                "CRITICAL"
            ],
            "event_name" : "Application",
            "log_group_name" : logGroupName,
            "log_stream_name" : "{instance_id}/Application"
        },
        {
            "event_format" : "xml",
            "event_levels" : [
                "INFORMATION",
                "WARNING",
                "ERROR",
                "CRITICAL"
            ],
            "event_name" : "Security",
            "log_group_name" : logGroupName,
            "log_stream_name" : "{instance_id}/Security"
        }
    ]]


    [#local agentConfig += {
        "logs" : {
            "logs_collected" : {
                "files" : {
                    "collect_list" : logFileConfigs
                },
                "windows_events" : {
                    "collect_list" : windowsEventLogs
                }
            }
        }
    }]

    [#-- OS Level Metric Collection for Memory and Disk Space --]
    [#local agentConfig += {
        "metrics" : {
            "namespace" : "CWAgent",
            "append_dimensions" : {
                "AutoScalingGroupName" : r'${aws:AutoScalingGroupName}',
                "InstanceId" : r'${aws:InstanceId}',
                "InstanceType" : r'${aws:InstanceType}'
            },
            "aggregation_dimensions" : [
                [ "AutoScalingGroupName", "InstanceId" ]
            ],
            "metrics_collected" : {
                "LogicalDisk" : {
                    "measurement" : [
                        "% Free Space"
                    ],
                    "metrics_collection_interval" : 60,
                    "resources" : [ "*" ]
                },
                "Memory" : {
                    "measurement" : [
                        "% Committed Bytes In Use"
                    ],
                    "metrics_collection_interval" : 60
                }
            }
        }
    }]

    [#-- compensate for getJSON escaping on leading / in string value --]
    [#local agentConfigArray = []]
    [#list getJSON(agentConfig, false, true)?split('\n') as acLine]
        [#local agentConfigArray += [ acLine?replace(r'"\/','"/') ] ]
    [/#list]

    [@computeTaskConfigSection
        computeTaskTypes=[ COMPUTE_TASK_SYSTEM_LOG_FORWARDING ]
        id="CloudWatchLogs"
        priority=2
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content={
            "packages" : {
                "msi" : {
                    "cloudwatch": "https://s3.amazonaws.com/amazoncloudwatch-agent/windows/amd64/latest/amazon-cloudwatch-agent.msi"
                }
            },
            "files" : {
                "c:\\ProgramData\\Hamlet\\Scripts\\awslogs.ps1" : {
                    "content" : {
                        "Fn::Join" : [
                            "\n",
                            [
                                r'Start-Transcript -Path c:\ProgramData\Hamlet\Logs\awslogs.log ;',
                                r'echo "Metadata log details" ;',
                                r'try {',
                                r'   $ecs_cluster=(Invoke-WebRequest -UseBasicParsing "http://localhost:51678/v1/metadata" | Select-Object -Property Content | ConvertFrom-Json | Select-Object -Property Cluster )',
                                r'} catch {',
                                r'   $ecs_cluster=""',
                                r'}'
                                r'try {',
                                r'   $ecs_container_instance_id=(Invoke-WebRequest -UseBasicParsing "http://localhost:51678/v1/metadata" | Select-Object -Property Content  | ConvertFrom-Json | Select-Object -Property ContainerInstanceArn) ;',
                                r'} catch {',
                                r'   $ecs_container_instance_id=""',
                                r'}'
                                r'echo "Gather mandatory Metadata" ;',
                                r'$macs=(Invoke-WebRequest -UseBasicParsing "http://169.254.169.254/latest/meta-data/network/interfaces/macs/" | select -First 1 ) ;',
                                r'$vpc_id=(Invoke-WebRequest -UseBasicParsing "http://169.254.169.254/latest/meta-data/network/interfaces/macs/$macs/vpc-id" ) ;',
                                r'$instance_id=(Invoke-WebRequest -UseBasicParsing "http://169.254.169.254/latest/meta-data/instance-id") ;',
                                r'',
                                r'function sed($fileName){',
                                r'   $tempFile = "c:\Temp\$($fileName | Split-Path -Leaf)"',
                                r'   (Get-Content -Path $fileName) -replace "{instance_id}", $instance_id -replace "{ecs_container_instance_id}", $ecs_container_instance_id -replace "{ecs_cluster}", $ecs_cluster -replace "{vpc_id}", $vpc_id | Add-Content -Path $tempFile',
                                r'   Remove-Item -Path $fileName',
                                r'   Copy-Item -Path $tempFile -Destination $fileName',
                                r'   echo "SED lastexitcode = $lastexitcode"',
                                r'   echo "SED errorcode = $?"',
                                r'}',
                                r'',
                                r'Stop-Transcript | out-null'
                            ]
                        ]
                    },
                    "mode" : "000755"
                },
                "c:\\Program Files\\Amazon\\AmazonCloudWatchAgent\\config.json": {
                    "content": {
                        "Fn::Join" : [
                            "\n",
                            agentConfigArray
                        ]
                    },
                    "mode": "000644"
                }
            },
            "commands": {
                "ConfigureLogsAgent" : {
                    "command" : "powershell.exe -ExecutionPolicy Bypass -Command c:\\ProgramData\\Hamlet\\Scripts\\awslogs.ps1",
                    "ignoreErrors" : false
                },
                "StartLogsAgent" : {
                    "command" : 'powershell.exe -ExecutionPolicy Bypass -Command .\\amazon-cloudwatch-agent-ctl.ps1 -a fetch-config -m ec2 -c file:"config.json" -s ',
                    "ignoreErrors" : false,
                    "cwd" : "C:\\Program Files\\Amazon\\AmazonCloudWatchAgent"
                }
            }
        }
    /]

[/#macro]
