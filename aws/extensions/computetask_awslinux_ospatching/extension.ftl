[#ftl]

[@addExtension
    id="computetask_awslinux_ospatching"
    aliases=[
        "_computetask_awslinux_ospatching"
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

[#macro shared_extension_computetask_awslinux_ospatching_deployment_computetask occurrence ]

    [#local OSPatching = _context.InstanceOSPatching ]
    [#local schedule = OSPatching.Schedule ]
    [#local securityOnly = OSPatching.SecurityOnly ]

    [#local solution = occurrence.Configuration.Solution ]
    [#local operatingSystem = solution.ComputeInstance.OperatingSystem]

    [#local updateCommand = ""]
    [#local content = ""]

    [#switch operatingSystem.Family ]
        [#case "linux" ]
            [#switch operatingSystem.Distribution ]
                [#case "awslinux" ]
                    [#switch operatingSystem.MajorVersion ]
                        [#case "1" ]
                        [#case "2"]
                            [#local updateCommand = "yum clean all && yum -y update"]
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
                                            "command" : 'echo \"${schedule} ${updateCommand} --security >> /var/log/update.log 2>&1\" >crontab.txt && crontab crontab.txt',
                                            "ignoreErrors" : false
                                        }
                                    },
                                    {
                                        "DailyUpdates" : {
                                            "command" : 'echo \"${schedule} ${updateCommand} >> /var/log/update.log 2>&1\" >crontab.txt && crontab crontab.txt',
                                            "ignoreErrors" : false
                                        }
                                    }
                                )
                            }]
                            [#break]
                        [#case "2023"]
                            [#local updateCommand = "dnf clean all && dnf -y update"]
                            [#local content = {
                                "packages": {
                                    "yum": {
                                        "cronie": []
                                    }
                                },
                                "commands": {
                                    "00EnableCrond": {
                                        "command": "systemctl enable --now crond"
                                    },
                                    "02CreateUpdateLog": {
                                        "command": "touch /var/log/update.log && chmod 644 /var/log/update.log",
                                        "ignoreErrors": false
                                    },
                                    "InitialUpdate" : {
                                        "command" : updateCommand,
                                        "ignoreErrors" : false
                                    }
                                } +
                                securityOnly?then(
                                    {
                                        "DailySecurity" : {
                                            "command" : "echo '${schedule} ${updateCommand} --security >> /var/log/update.log 2>&1' > /etc/cron.d/dnf-updates && chmod 644 /etc/cron.d/dnf-updates",
                                            "ignoreErrors" : false
                                        }
                                    },
                                    {
                                        "DailyUpdates" : {
                                            "command" : "echo '${schedule} ${updateCommand} >> /var/log/update.log 2>&1' > /etc/cron.d/dnf-updates && chmod 644 /etc/cron.d/dnf-updates",
                                            "ignoreErrors" : false
                                        }
                                    }
                                )
                            }]
                            [#break]
                    [/#switch]
                    [#break]
            [/#switch]
            [#break]
        [#break]
    [/#switch]

    [#if OSPatching.Enabled ]
        [#local content = content]
    [#else]
        [#local content = {
            "copmmands" : {
                "PatchWarning" : {
                    "command" : 'echo "OS Patching Disabled" >> /var/log/update.log',
                    "ignoreErrors" : false
                }
            }
        }]
    [/#if]

    [@computeTaskConfigSection
        computeTaskTypes=[ 
            COMPUTE_TASK_OS_SECURITY_PATCHING, 
            COMPUTE_TASK_ANTIVIRUS_CONFIG 
        ]
        id="OSPatching"
        priority=1
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content=content
    /]
[/#macro]
