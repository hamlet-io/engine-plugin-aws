[#ftl]

[@addExtension
    id="computetask_awswin_filedir"
    aliases=[
        "_computetask_awswin_filedir"
    ]
    description=[
        "Uses windows commands to create files and directories"
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

[#function scope2win scope]
    [#local scope = scope?upper_case]
    [#switch scope[0..*1]]
        [#case "U"]
            [#return 3]
        [#break]
        [#case "G"]
            [#return 4]
        [#break]
        [#case "O"]
            [#return 5]
        [#break]
    [/#switch]
[/#function]

[#function chmod2win scope chmodval]
    [#local chmodval = (chmodval?length == 3)?then(
                                    chmodval?left_pad(6, "0"),
                                    chmodval )]
    [#local scope = scope?upper_case]
    [#switch chmodval[scope2win(scope)..*1]]
        [#case "7"]
            [#return "F"]
        [#break]
        [#case "6"]
            [#return "M"]
        [#break]
        [#case "5"]
            [#return "RX"]
        [#break]
        [#case "4"]
            [#return "R"]
        [#break]
        [#case "3"]
            [#return "W"]
        [#break]
        [#case "2"]
            [#return "W"]
        [#break]
        [#case "1"]
            [#return "X"]
        [#break]
        [#case "0"]
            [#return "N"]
        [#break]
    [/#switch]
[/#function]

[#macro shared_extension_computetask_awswin_filedir_deployment_computetask occurrence ]

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
        "Start-Transcript -Path c:\\ProgramData\\Hamlet\\Logs\\user-step.log -Append ;",
        r'echo "Directory and File Creation" ;'
    ]]

    [#list directories as directoryName,directory ]

        [#local mode = directory.mode ]
        [#local owner = directory.owner ]
        [#local group = directory.group ]

        [#local ownerPerm = chmod2win("U", mode)]
        [#local groupPerm = chmod2win("G", mode)]

        [#local initDirFile += [
            'New-Item -ItemType Directory -Force -Path ${directoryName}',
            'ICACLS ${directoryName} /setowner ${owner}',
            'ICACLS ${directoryName} /grant ${owner}:${ownerPerm} /inheritance:e',
            'ICACLS ${directoryName} /grant ${group}:${groupPerm} /inheritance:e'
        ]]
    [/#list]
    [#local initDirFile += [
        "Stop-Transcript | out-null"
    ]]



    [#local content = {}]
    [#if files?has_content || directories?has_content ]
        [#local content = {} +
            attributeIfContent(
                "CreateDirs",
                directories,
                {
                    "files" : {
                        "c:\\ProgramData\\Hamlet\\Scripts\\create_dirs.ps1" : {
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
                            "command" : "powershell.exe -ExecutionPolicy Bypass -Command c:\\ProgramData\\Hamlet\\Scripts\\create_dirs.ps1",
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
