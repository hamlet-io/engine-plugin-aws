[#ftl]

[@addExtension
    id="computetask_linux_filedir"
    aliases=[
        "_computetask_linux_filedir"
    ]
    description=[
        "Uses linux commands to create files and directories"
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

[#macro shared_extension_computetask_linux_filedir_deployment_computetask occurrence ]

    [#local files = _context.Files ]
    [#local directories = _context.Directories ]

    [#local initFiles = {} ]
    [#list files as fileName,file ]

        [#local fileMode = (file.mode?length == 3)?then(
                                    file.mode?left_pad(6, "0"),
                                    file.mode )]

        [#local initFiles +=
            {
                fileName : {
                    "content" : {
                        "Fn::Join" : [
                            "\n",
                            file.content
                        ]
                    },
                    "group" : file.group,
                    "owner" : file.owner,
                    "mode"  : fileMode
                }
            }]
    [/#list]

    [#local initDirFile = [
        '#!/bin/bash',
        'exec > >(tee /var/log/hamlet_cfninit/dirsfiles.log | logger -t codeontap-dirsfiles -s 2>/dev/console) 2>&1'
    ]]

    [#list directories as directoryName,directory ]

        [#local mode = directory.mode ]
        [#local owner = directory.owner ]
        [#local group = directory.group ]

        [#local initDirFile += [
            'if [[ ! -d "${directoryName}" ]]; then',
            '   mkdir --parents --mode="${mode}" "${directoryName}"',
            '   chown ${owner}:${group} "${directoryName}"',
            'else',
            '   chown -R ${owner}:${group} "${directoryName}"',
            '   chmod ${mode} "${directoryName}"',
            'fi'
        ]]
    [/#list]


    [#local content = {}]
    [#if files?has_content || directories?has_content ]
        [#local content = {
            "commands" : {
                "status" : {
                    "command" : r'echo "Direcotry and File Creation" >> /var/log/hamlet_cfninit/dirsfiles.log'
                }
            } } +
            attributeIfContent(
                "CreateDirs",
                directories,
                {
                    "files" : {
                        "/opt/hamlet_cfninit/create_dirs.sh" : {
                            "content" : {
                                "Fn::Join" : [
                                    "\n",
                                    initDirFile
                                ]
                            },
                            "mode" : "000755"
                        }
                    },
                    "commands" : {
                        "CreateDirScript" : {
                            "command" : "/opt/hamlet_cfninit/create_dirs.sh",
                            "ignoreErrors" : false
                        }
                    }
                }
            ) +
            attributeIfContent(
                "CreateFiles",
                files,
                {
                    "files" : initFiles
                }

            )]
    [/#if]

    [@computeTaskConfigSection
        computeTaskTypes=[ COMPUTE_TASK_FILE_DIR_CREATION ]
        id="FileDirectories"
        priority=3
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content=content
    /]

[/#macro]
