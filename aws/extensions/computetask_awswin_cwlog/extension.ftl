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

[#function windows_path_converter nix_path ]
    [#local retval = nix_path?replace("/awsssm/", r"c:\ProgramData\Amazon\SSM\Logs\")]
    [#local retval = retval?replace("/ec2/", r"c:\ProgramData\Amazon\EC2-Windows\Launch\Log\")]
    [#local retval = retval?replace("/cwa/", r"c:\ProgramData\Amazon\AmazonCloudWatchAgent\Logs\")]

    [#local retval = retval?replace("/var/log/", r"C:\ProgramData\Hamlet\Logs\")]
    [#local retval = retval?replace("/", r"\")]
    [#local retval = retval?replace(r"\", r"\\")]
    [#return retval ]
[/#function]

[#macro shared_extension_computetask_awswin_cwlog_deployment_computetask occurrence ]

    [#local solution = occurrence.Configuration.Solution ]

    [#local logFileProfile = _context.LogFileProfile ]
    [#local logGroupName = _context.InstanceLogGroup ]

    [#local logContent = []]

    [#list logFileProfile.LogFileGroups as logFileGroup ]
        [#local logGroup = logFileGroups[logFileGroup] ]
        [#list logGroup.LogFiles as logFile ]
            [#local logFileDetails = logFiles[logFile] ]
            [#local timeFormat = logFileDetails.TimeFormat]
            [#local timeFormat = timeFormat!'%Y/%m/%d %H:%M:%S%Z']
            [#local logContent +=
                [
                    r'{',
                    r'    "file_path": "' + windows_path_converter(logFileDetails.FilePath) + '",',
                    r'    "log_group_name": "' + logGroupName + '",',
                    r'    "log_stream_name": "{instance_id}' + logFileDetails.FilePath + '",',
                    r'    "timestamp_format": "' + timeFormat + '" ',
                    r'},'
                ]
            ]
        [/#list]
    [/#list]

    [#local solution = occurrence.Configuration.Solution ]
    [#local operatingSystem = solution.ComputeInstance.OperatingSystem]

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
                                r'   $ecs_cluster=(Invoke-WebRequest "http://localhost:51678/v1/metadata" | Select-Object -Property Content | ConvertFrom-Json | Select-Object -Property Cluster )',
                                r'} catch {',
                                r'   $ecs_cluster=""',
                                r'}'
                                r'try {',
                                r'   $ecs_container_instance_id=(Invoke-WebRequest "http://localhost:51678/v1/metadata" | Select-Object -Property Content  | ConvertFrom-Json | Select-Object -Property ContainerInstanceArn) ;',
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
                                r'sed "c:\ProgramData\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent.json" ;',
                                r'Stop-Transcript | out-null'
                            ]
                        ]
                    },
                    "mode" : "000755"
                },
                "c:\\ProgramData\\Amazon\\AmazonCloudWatchAgent\\amazon-cloudwatch-agent.json": {
                    "content": {
                        "Fn::Join" : [
                            "\n",
                            [
                                r'{ ',
                                r'    "IsEnabled": true, ',
                                r'    "EngineConfiguration": { ',
                                r'        "PollInterval": "00:00:15", ',
                                r'        "Components": [ ',
                                r'            { ',
                                r'                "Id": "ApplicationEventLog", ',
                                r'                "FullName": "AWS.EC2.Windows.CloudWatch.EventLog.EventLogInputComponent,AWS.EC2.Windows.CloudWatch", ',
                                r'                "Parameters": { ',
                                r'                    "LogName": "Application", ',
                                r'                    "Levels": "1" ',
                                r'                } ',
                                r'            }, ',
                                r'            { ',
                                r'                "Id": "SystemEventLog", ',
                                r'                "FullName": "AWS.EC2.Windows.CloudWatch.EventLog.EventLogInputComponent,AWS.EC2.Windows.CloudWatch", ',
                                r'                "Parameters": { ',
                                r'                    "LogName": "System", ',
                                r'                    "Levels": "7" ',
                                r'                } ',
                                r'            }, ',
                                r'            { ',
                                r'                "Id": "SecurityEventLog", ',
                                r'                "FullName": "AWS.EC2.Windows.CloudWatch.EventLog.EventLogInputComponent,AWS.EC2.Windows.CloudWatch", ',
                                r'                "Parameters": { ',
                                r'                "LogName": "Security", ',
                                r'                "Levels": "7" ',
                                r'                } ',
                                r'            }, ',
                                r'            { ',
                                r'                "Id": "ETW", ',
                                r'                "FullName": "AWS.EC2.Windows.CloudWatch.EventLog.EventLogInputComponent,AWS.EC2.Windows.CloudWatch", ',
                                r'                "Parameters": { ',
                                r'                    "LogName": "Microsoft-Windows-WinINet/Analytic", ',
                                r'                    "Levels": "7" ',
                                r'                } ',
                                r'            }, ',
                                r'            { ',
                                r'                "Id": "IISLogs", ',
                                r'                "FullName": "AWS.EC2.Windows.CloudWatch.CustomLog.CustomLogInputComponent,AWS.EC2.Windows.CloudWatch", ',
                                r'                "Parameters": { ',
                                r'                    "LogDirectoryPath": "C:\\inetpub\\logs\\LogFiles\\W3SVC1", ',
                                r'                    "TimestampFormat": "yyyy-MM-dd HH:mm:ss", ',
                                r'                    "Encoding": "UTF-8", ',
                                r'                    "Filter": "", ',
                                r'                    "CultureName": "en-US", ',
                                r'                    "TimeZoneKind": "UTC", ',
                                r'                    "LineCount": "3" ',
                                r'                } ',
                                r'            }, ',
                                r'            { ',
                                r'                "Id": "SSMLogs", ',
                                r'                "FullName": "AWS.EC2.Windows.CloudWatch.CustomLog.CustomLogInputComponent,AWS.EC2.Windows.CloudWatch", ',
                                r'                "Parameters": { ',
                                r'                    "LogDirectoryPath": "C:\\ProgramData\\Amazon\\SSM\\Logs\\", ',
                                r'                    "TimestampFormat": "yyyy-MM-dd HH:mm:ss", ',
                                r'                    "Encoding": "UTF-8", ',
                                r'                    "Filter": "", ',
                                r'                    "CultureName": "en-US", ',
                                r'                    "TimeZoneKind": "Local", ',
                                r'                    "LogStream": "{instance_id}/ssm" ',
                                r'                } ',
                                r'            }, ',
                                r'            { ',
                                r'                "Id": "CustomLogs", ',
                                r'                "FullName": "AWS.EC2.Windows.CloudWatch.CustomLog.CustomLogInputComponent,AWS.EC2.Windows.CloudWatch", ',
                                r'                "Parameters": { ',
                                r'                    "LogDirectoryPath": "C:\\ProgramData\\Hamlet\\Logs\\", ',
                                r'                    "TimestampFormat": "dd/MM/yyyy HH:mm:ss", ',
                                r'                    "Encoding": "UTF-8", ',
                                r'                    "Filter": "", ',
                                r'                    "CultureName": "en-US", ',
                                r'                    "TimeZoneKind": "Local" ',
                                r'                } ',
                                r'            }, ',
                                r'            { ',
                                r'                "Id": "PerformanceCounter", ',
                                r'                "FullName": "AWS.EC2.Windows.CloudWatch.PerformanceCounterComponent.PerformanceCounterInputComponent,AWS.EC2.Windows.CloudWatch", ',
                                r'                "Parameters": { ',
                                r'                    "CategoryName": "Memory", ',
                                r'                    "CounterName": "Available MBytes", ',
                                r'                    "InstanceName": "", ',
                                r'                    "MetricName": "Memory", ',
                                r'                    "Unit": "Megabytes", ',
                                r'                    "DimensionName": "", ',
                                r'                    "DimensionValue": "" ',
                                r'                } ',
                                r'            }, ',
                                r'            { ',
                                r'                "Id": "CloudWatchLogs", ',
                                r'                "FullName": "AWS.EC2.Windows.CloudWatch.CloudWatchLogsOutput,AWS.EC2.Windows.CloudWatch", ',
                                r'                "Parameters": { ',
                                r'                    "AccessKey": "", ',
                                r'                    "SecretKey": "", ',
                                r'                    "Region": "us-east-1", ',
                                r'                    "LogGroup": "Default-Log-Group", ',
                                r'                    "LogStream": "{instance_id}" ',
                                r'                } ',
                                r'            }, ',
                                r'            { ',
                                r'                "Id": "CloudWatch", ',
                                r'                "FullName": "AWS.EC2.Windows.CloudWatch.CloudWatch.CloudWatchOutputComponent,AWS.EC2.Windows.CloudWatch", ',
                                r'                "Parameters":  ',
                                r'                { ',
                                r'                    "AccessKey": "", ',
                                r'                    "SecretKey": "", ',
                                r'                    "Region": "us-east-1", ',
                                r'                    "NameSpace": "Windows/Default" ',
                                r'                } ',
                                r'            } ',
                                r'        ], ',
                                r'        "Flows": { ',
                                r'            "Flows":  ',
                                r'            [ ',
                                r'                "(ApplicationEventLog,SystemEventLog),CloudWatchLogs", ',
                                r'                "PerformanceCounter,CloudWatch" ',
                                r'            ] ',
                                r'        } ',
                                r'    } ',
                                r'} '
                            ]
                        ]
                    },
                    "mode" : "000755"
                },
                "c:\\Program Files\\Amazon\\AmazonCloudWatchAgent\\config.json": {
                    "content": {
                        "Fn::Join" : [
                            "\n",
                            [
                                r'{ ',
                                r'    "logs": { ',
                                r'        "logs_collected": { ',
                                r'            "files": { ',
                                r'                "collect_list": [ '
                            ] +
                            logContent +
                            [
                                r'                    { ',
                                r'                        "file_path": "c:\\ProgramData\\Hamlet\\Logs", ',
                                r'                        "log_group_name": "' + logGroupName + '", ',
                                r'                        "log_stream_name": "{instance_id}/hamletlogs" ',
                                r'                    } ',
                                r'                ] ',
                                r'            }, ',
                                r'            "windows_events": { ',
                                r'                "collect_list": [ ',
                                r'                    { ',
                                r'                        "event_format": "xml", ',
                                r'                        "event_levels": [ ',
                                r'                            "VERBOSE", ',
                                r'                            "INFORMATION", ',
                                r'                            "WARNING", ',
                                r'                            "ERROR", ',
                                r'                            "CRITICAL" ',
                                r'                        ], ',
                                r'                        "event_name": "System", ',
                                r'                        "log_group_name": "' + logGroupName + '", ',
                                r'                        "log_stream_name": "{instance_id}/system" ',
                                r'                    }, ',
                                r'                    { ',
                                r'                        "event_format": "xml", ',
                                r'                        "event_levels": [ ',
                                r'                            "WARNING", ',
                                r'                            "ERROR", ',
                                r'                            "CRITICAL" ',
                                r'                        ], ',
                                r'                        "event_name": "Application", ',
                                r'                        "log_group_name": "' + logGroupName + '", ',
                                r'                        "log_stream_name": "{instance_id}/application" ',
                                r'                    }, ',
                                r'                    { ',
                                r'                        "event_format": "xml", ',
                                r'                        "event_levels": [ ',
                                r'                            "VERBOSE", ',
                                r'                            "INFORMATION", ',
                                r'                            "WARNING", ',
                                r'                            "ERROR", ',
                                r'                            "CRITICAL" ',
                                r'                        ], ',
                                r'                        "event_name": "Security", ',
                                r'                        "log_group_name": "' + logGroupName + '", ',
                                r'                        "log_stream_name": "{instance_id}/security" ',
                                r'                    } ',
                                r'                ] ',
                                r'            } ',
                                r'        } ',
                                r'    }, ',
                                r'    "metrics": { ',
                                r'        "append_dimensions": { ',
                                r'            "AutoScalingGroupName": "${aws:AutoScalingGroupName}", ',
                                r'            "ImageId": "${aws:ImageId}", ',
                                r'            "InstanceId": "${aws:InstanceId}", ',
                                r'            "InstanceType": "${aws:InstanceType}" ',
                                r'        }, ',
                                r'        "metrics_collected": { ',
                                r'            "LogicalDisk": { ',
                                r'                "measurement": [ ',
                                r'                    "% Free Space" ',
                                r'                ], ',
                                r'                "metrics_collection_interval": 60, ',
                                r'                "resources": [ ',
                                r'                    "*" ',
                                r'                ] ',
                                r'            }, ',
                                r'            "Memory": { ',
                                r'                "measurement": [ ',
                                r'                    "% Committed Bytes In Use" ',
                                r'                ], ',
                                r'                "metrics_collection_interval": 60 ',
                                r'            }, ',
                                r'            "statsd": { ',
                                r'                "metrics_aggregation_interval": 60, ',
                                r'                "metrics_collection_interval": 10, ',
                                r'                "service_address": ":8125" ',
                                r'            } ',
                                r'        } ',
                                r'    } ',
                                r'} '
                            ]
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
