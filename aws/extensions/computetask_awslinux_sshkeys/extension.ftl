[#ftl]

[@addExtension
    id="computetask_linux_sshkeys"
    aliases=[
        "_computetask_linux_sshkeys"
    ]
    description=[
        "Add additional SSH keys to the default ec2-user account"
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

[#macro shared_extension_computetask_linux_sshkeys_deployment_computetask occurrence ]

    [#local SSHPublicKeysContent = [] ]

    [#list _context.Links as linkId,linkTarget]
        [#local linkTargetCore = linkTarget.Core ]
        [#local linkTargetConfiguration = linkTarget.Configuration ]
        [#local linkTargetResources = linkTarget.State.Resources ]
        [#local linkTargetAttributes = linkTarget.State.Attributes ]
        [#local linkTargetRoles = linkTarget.State.Roles]

        [#switch linkTargetCore.Type]
            [#case USER_COMPONENT_TYPE]
                [#local SSHPublicKeys = linkTargetConfiguration.Solution.SSHPublicKeys ]
                [#local linkEnvironment = linkTargetConfiguration.Environment.General ]
                [#list SSHPublicKeys as id,publicKey ]
                    [#if (linkEnvironment[publicKey.SettingName])?has_content ]
                        [#local SSHPublicKeysContent += [ "${linkEnvironment[publicKey.SettingName]} ${id}" ]]
                    [/#if]
                [/#list]
                [#break]
        [/#switch]
    [/#list]

    [#local content = {}]
    [#if SSHPublicKeysContent?has_content ]
        [#local content = {
            "files" :{
                "/home/ec2-user/.ssh/authorized_keys_hamlet" : {
                    "content" : {
                        "Fn::Join" : [
                            "\n",
                            SSHPublicKeysContent
                        ]
                    },
                    "mode" : "000600",
                    "group" : "ec2-user",
                    "owner" : "ec2-user"
                }
            },
            "commands": {
                "01UpdateSSHDConfig" : {
                    "command" : "sed -i 's#^\\(AuthorizedKeysFile.*$\\)#\\1 .ssh/authorized_keys_hamlet#' /etc/ssh/sshd_config",
                    "ignoreErrors" : false
                }
            },
            "services" : {
                "sysvinit" :{
                    "sshd" : {
                        "ensureRunning" : true,
                        "files" : [ "/home/ec2-user/.ssh/authorized_keys_hamlet" ]
                    }
                }
            }
        }]
    [/#if]

    [@computeTaskConfigSection
        computeTaskTypes=[ COMPUTE_TASK_USER_ACCESS ]
        id="SSHKeys"
        priority=5
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content=content
    /]

[/#macro]
