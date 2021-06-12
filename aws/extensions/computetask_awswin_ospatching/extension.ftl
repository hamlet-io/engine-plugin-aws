[#ftl]

[@addExtension
    id="computetask_awswin_ospatching"
    aliases=[
        "_computetask_awswin_ospatching"
    ]
    description=[
        "Creates a cron based yum update for security patching"
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
    [#local schedule = OSPatching.Schedule ]
    [#local securityOnly = OSPatching.SecurityOnly ]

    [#local updateCommand = "<script>rem Windows no update command - yum clean all && yum -y update</script>"]

<!-- Windows instances are patched by new AMIs - normally test OSPatching.Enabled in if below -->
    [#if false ]
        [#local content = {
                "commands": {
                    "InitialUpdate" : {
                        "command" : updateCommand,
                        "ignoreErrors" : false
                    }
                } +
                securityOnly?then(
                    {
                        "DailySecurity" : {
                            "command" : '<script>echo \"${schedule} ${updateCommand} --security >> c:\\ProgramData\\Hamlet\\Logs\\update.log\" >crontab.txt && crontab crontab.txt</script>',
                            "ignoreErrors" : false
                        }
                    },
                    {
                        "DailyUpdates" : {
                            "command" : '<script>echo \"${schedule} ${updateCommand} >> c:\\ProgramData\\Hamlet\\Logs\\update.log\" >crontab.txt && crontab crontab.txt</script>',
                            "ignoreErrors" : false
                        }
                    }
                )
            }]
    [#else]
        [#local content = {
        }]
    [/#if]

    [@computeTaskConfigSection
        computeTaskTypes=[ COMPUTE_TASK_OS_SECURITY_PATCHING ]
        id="OSPatching"
        priority=1
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content=content
    /]
[/#macro]
