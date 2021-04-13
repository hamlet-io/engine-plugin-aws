[#ftl]

[@addExtension
    id="computetask_linux_userbootstrap"
    aliases=[
        "_computetask_linux_userbootstrap"
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

[#macro shared_extension_computetask_linux_userbootstrap_deployment_computetask occurrence ]

    [#local environment = getFinalEnvironment(occurrence, _context ).Environment ]

    [#local files = {}]
    [#local commands = {}]
    [#local userBootstrapPackages = {}]

    [#local bootstrapProfile = _context.BootstrapProfile ]

    [#list bootstrapProfile.BootStraps as bootstrapName ]
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

        [#local bootstrapDir = "/opt/hamlet/user/" + boostrapName ]
        [#local bootstrapFetchFile = bootstrapDir + "/fetch.sh" ]
        [#local bootstrapScriptsDir = bootstrapDir + "/scripts/" ]
        [#local bootstrapInitFile = bootstrapScriptsDir + bootstrap.InitScript!"init.sh" ]


        [#local files += {
            bootstrapFetchFile: {
                "content" : {
                    "Fn::Join" : [
                        "\n",
                        [
                            "#!/bin/bash -ex",
                            "exec > >(tee /var/log/hamlet_cfninit/fetch.log | logger -t codeontap-fetch -s 2>/dev/console) 2>&1",
                            {
                                "Fn::Sub" : [
                                    r'BOOTSTRAP_SCRIPTS_DIR="${BootstrapScriptsDir}"',
                                    {
                                        "BootstrapScriptsDir" : bootstrapScriptsDir
                                    }
                                ]
                            },
                            {
                                "Fn::Sub" : [
                                    r'aws --region "${Region}" s3 sync "s3://${CodeBucket}/${ScriptStorePrefix}" "${!BOOTSTRAP_SCRIPTS_DIR}"',
                                    {
                                        "Region" : { "Ref" : "AWS::Region" },
                                        "CodeBucket" : codeBucket,
                                        "ScriptStorePrefix" : scriptStorePrefix
                                    }
                                ]
                            },
                            r'find "${!BOOTSTRAP_SCRIPTS_DIR}" -type f -exec chmod u+rwx {} \\;'
                        ]
                    ]
                },
                "mode" : "000755"
            }
        } ]

        [#local commands += {
            "01Fetch_${bootstrapFetchFile}" : {
                "command" : bootstrapFetchFile,
                "ignoreErrors" : false
            },
            "02RunScript_${bootstrapInitFile}" : {
                "command" : bootstrapInitFile,
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
