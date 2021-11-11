[#ftl]

[@addExtension
    id="computetask_awslinux_efsmount"
    aliases=[
        "_computetask_awslinux_efsmount"
    ]
    description=[
        "Mount efs component mount points using efs-utils"
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

[#macro shared_extension_computetask_awslinux_efsmount_deployment_computetask occurrence ]

    [#local solution = occurrence.Configuration.Solution ]

    [#local files = {}]
    [#local commands = {}]

    [#list _context.Links as linkId,linkTarget]
        [#local linkTargetCore = linkTarget.Core ]
        [#local linkTargetAttributes = linkTarget.State.Attributes ]

        [#switch linkTargetCore.Type]
            [#case FILESHARE_COMPONENT_TYPE ]
            [#case FILESHARE_MOUNT_COMPONENT_TYPE]

                [#local mountId = linkTargetCore.Id]
                [#local efsId = linkTargetAttributes.EFS]
                [#local directory = linkTargetAttributes.DIRECTORY]
                [#local osMount = linkId]
                [#local accessPointId=   (linkTargetAttributes.ACCESS_POINT_ID)!"" ]

                [#local createMount = true]
                [#if directory == "/" ]
                    [#local createMount = false ]
                [/#if]

                [#local scriptName = "efs_mount_${mountId}" ]

                [#local script = [
                    r'#!/bin/bash',
                    'exec > >(tee /var/log/hamlet_cfninit/${scriptName}.log | logger -t ${scriptName} -s 2>/dev/console) 2>&1'
                ]]

                [#local efsOptions = [ "_netdev", "tls", "iam"]]

                [#if accessPointId?has_content ]
                    [#local efsOptions += [ "accesspoint=${accessPointId}" ]]
                [/#if]

                [#local efsOptions = efsOptions?join(",")]

                [#if createMount ]
                    [#local script += [
                        r'# Create mount dir in EFS',
                        r'temp_dir="$(mktemp -d -t efs.XXXXXXXX)"',
                        r'mount -t efs "${efsId}:/" ${temp_dir} || exit $?',
                        r'if [[ ! -d "${temp_dir}/' + directory + r' ]]; then',
                        r'  mkdir -p "${temp_dir}/' + directory + r'"',
                        r'  # Allow Full Access to volume (Allows for unkown container access )',
                        r'  chmod -R ugo+rwx "${temp_dir}/' + directory + r'"',
                        r'fi',
                        r'umount ${temp_dir}'
                    ]]
                [/#if]

                [#local mountPath = "/mnt/clusterstorage/${osMount}" ]

                [#local script += [
                    'mkdir -p "${mountPath}"',
                    'mount -t efs -o "${efsOptions}" "${efsId}:${directory}" "${mountPath}"',
                    'echo -e "${efsId}:${directory} ${mountPath} efs ${efsOptions} 0 0" >> /etc/fstab'
                ]]

                [#local files += {
                    "/opt/hamlet_cfninit/${scriptName}.sh" : {
                        "content" : {
                            "Fn::Join" : [
                                "\n",
                                script
                            ]
                        },
                        "mode" : "000755"
                    }
                }]

                [#local commands += {
                    scriptName : {
                        "command" : "/opt/hamlet_cfninit/${scriptName}.sh",
                        "ignoreErrors" : false
                    }
                }]

                [#break]
        [/#switch]
    [/#list]

    [#local content = {} ]
    [#if files?has_content && commands?has_content ]
        [#local content =
            {
                "packages" : {
                    "yum" : {
                        "amazon-efs-utils" : []
                    }
                },
                "files" : files,
                "commands" :  commands
            }
        ]
    [/#if]

    [@computeTaskConfigSection
        computeTaskTypes=[ COMPUTE_TASK_EFS_MOUNT ]
        id="EFSMounts"
        priority=4
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content=content
    /]
[/#macro]
