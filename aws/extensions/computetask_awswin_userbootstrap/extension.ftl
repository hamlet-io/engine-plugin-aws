[#ftl]

[@addExtension
    id="computetask_awswin_userbootstrap"
    aliases=[
        "_computetask_awswin_userbootstrap"
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

[#macro shared_extension_computetask_awswin_userbootstrap_deployment_computetask occurrence ]

    [#local environment = getFinalEnvironment(occurrence, _context ).Environment ]

    [#local files = {}]
    [#local commands = {}]
    [#local userBootstrapPackages = {}]

    [#local bootstrapProfile = _context.BootstrapProfile ]

    [#list bootstrapProfile.Bootstraps as bootstrapName ]
        [#local bootstrap = bootstraps[bootstrapName]]

        [#local scriptStore = scriptStores[bootstrap.ScriptStore ]]
        [#local scriptStorePrefix = scriptStore.Destination.Prefix ]

        [#list bootstrap.Packages!{} as provider,packages ]
            [#local providerPackages = {}]
            [#if packages?is_sequence ]
                [#list packages as package ]
                    [#local providerPackages +=
                        {
                            package.Name : [] +
                                (package.Version)?has_content?then(
                                    [ package.Version ],
                                    []
                                )
                        }]
                [/#list]
            [/#if]
            [#if providerPackages?has_content ]
                [#local userBootstrapPackages +=
                    {
                        provider : providerPackages
                    }]
            [/#if]
        [/#list]

        [#local bootstrapDir = "c:\\ProgramData\\Hamlet\\" + boostrapName ]
        [#local bootstrapFetchFile = bootstrapDir + "\\fetch.ps1" ]
        [#local bootstrapScriptsDir = bootstrapDir + "\\scripts\\" ]
        [#local bootstrapInitFile = bootstrapScriptsDir + bootstrap.InitScript!"init.ps1" ]


        [#local files += {
            bootstrapFetchFile: {
                "content" : {
                    "Fn::Join" : [
                        "\n",
                        [
                            "Start-Transcript -Path c:\\ProgramData\\Hamlet\\Logs\\user-step.log -Append",
                            r'echo "Starting userbootstrap" '
                            {
                                "Fn::Sub" : [
                                    r'BOOTSTRAP_SCRIPTS_DIR="${BootstrapScriptsDir}"',
                                    {
                                        "BootstrapScriptsDir" : bootstrapScriptsDir
                                    }
                                ]
                            },
                            r'Set-Location -Path "C:\Program Files\Amazon\AWSCLIV2" ',
                            {
                                "Fn::Sub" : [
                                    r'.\aws --region "${Region}" s3 sync "s3://${CodeBucket}/${ScriptStorePrefix}" "${!BOOTSTRAP_SCRIPTS_DIR}" 2>&1 | Write-Output ',
                                    {
                                        "Region" : { "Ref" : "AWS::Region" },
                                        "CodeBucket" : getCodeBucket(),
                                        "ScriptStorePrefix" : scriptStorePrefix
                                    }
                                ]
                            },
                            r'$ACL = Get-Acl -Path "${!BOOTSTRAP_SCRIPTS_DIR}"',
                            r"ICACLS ${!BOOTSTRAP_SCRIPTS_DIR}\* /grant $ACL.Owner.Split('\')[1]:F /inheritance:e",
                            "Stop-Transcript | out-null"
                        ]
                    ]
                },
                "mode" : "000755"
            }
        } ]

        [#local commands += {
            "01Fetch_${bootstrapFetchFile}" : {
                "command" : "powershell.exe -ExecutionPolicy Bypass -Command "+bootstrapFetchFile,
                "ignoreErrors" : false
            },
            "02RunScript_${bootstrapInitFile}" : {
                "command" : "powershell.exe -ExecutionPolicy Bypass -Command "+bootstrapInitFile,
                "ignoreErrors" : false,
                "cwd" : bootstrapScriptsDir
            } +
            attributeIfContent(
                "env",
                environment
            )
        }]

    [/#list]

    [@computeTaskConfigSection
        computeTaskTypes=[ COMPUTE_TASK_USER_BOOTSTRAP ]
        id="UserBootstrap"
        priority=7
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content={} +
        attributeIfContent(
            "packages",
            userBootstrapPackages
        ) +
        attributeIfContent(
            "files",
            files
        ) +
        attributeIfContent(
            "commands",
            commands
        )
    /]

[/#macro]
