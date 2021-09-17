[#ftl]

[@addExtension
    id="computetask_awswin_ospatching"
    aliases=[
        "_computetask_awswin_ospatching"
    ]
    description=[
        "Windows OS Patching Warning"
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

[#macro shared_extension_computetask_awswin_ospatching_deployment_computetask occurrence ]

    [#local OSPatching = _context.InstanceOSPatching ]

    [#if OSPatching.Enabled ]
        [@warning
            message="Non-AMI based patching of OS is not supported on Windows Server"
            context=OSPatching
        /]

        [#local content = {
                "files": {
                    "c:\\ProgramData\\Hamlet\\Scripts\\av_tasks.ps1" : {
                        "content" : {
                            "Fn::Join" : [
                                "\n",
                                [
                                    "Start-Transcript -Path c:\\ProgramData\\Hamlet\\Logs\\user-step.log -Append ;",
                                    r'echo "AV Tasks - av_tasks.ps1" ;',
                                    r"Update-MpSignature ;",
                                    r"Stop-Transcript | out-null"
                                ]
                            ]
                        },
                        "mode" : "000755"
                    },
                    "c:\\ProgramData\\Hamlet\\Scripts\\schedule_tasks.ps1" : {
                        "content" : {
                            "Fn::Join" : [
                                "\n",
                                [
                                    "Start-Transcript -Path c:\\ProgramData\\Hamlet\\Logs\\user-step.log -Append ;",
                                    r'echo "Schedule Tasks - schedule_tasks.ps1" ;',
                                    r"$avAction = New-ScheduledTaskAction `",
                                    r"    -Execute 'powershell.exe' `",
                                    r"    -Argument '-File c:\ProgramData\Hamlet\Scripts\av_tasks.ps1' ;",
                                    r"$avTrigger = New-ScheduledTaskTrigger -Daily -At 3PM ;",
                                    r"$taskName = 'avRefresh' ;",
                                    r"$taskDesc = 'Refresh Windows Defender definition files' ;",
                                    r"Register-ScheduledTask `",
                                    r"    -TaskName $taskName `",
                                    r"    -Action $avAction `",
                                    r"    -Trigger $avTrigger `",
                                    r"    -Description $taskDesc ;",
                                    r"Stop-Transcript | out-null"
                                ]
                            ]
                        },
                        "mode" : "000755"
                    }
                },
                "commands": {
                    "InitialUpdate" : {
                        "command" : "powershell.exe -ExecutionPolicy Bypass -Command c:\\ProgramData\\Hamlet\\Scripts\\schedule_tasks.ps1",
                        "ignoreErrors" : false
                    }
                }
            }]
    [#else]
        [#local content={}]
    [/#if]

    [@computeTaskConfigSection
        computeTaskTypes=[ COMPUTE_TASK_OS_SECURITY_PATCHING ]
        id="OSPatching"
        priority=1
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content=content
    /]
[/#macro]
