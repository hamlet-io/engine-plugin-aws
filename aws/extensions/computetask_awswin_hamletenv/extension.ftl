[#ftl]

[@addExtension
    id="computetask_awswin_hamletenv"
    aliases=[
        "_computetask_awswin_hamletenv"
    ]
    description=[
        "Uses the shared profile configuration to set default environment varaibles"
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

[#macro shared_extension_computetask_awswin_hamletenv_deployment_computetask occurrence ]

    [#local baselineLinks = _context.BaselineLinks]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local operationsBucket = getExistingReference(baselineComponentIds["OpsData"]) ]
    [#local dataBucket = getExistingReference(baselineComponentIds["AppData"])]
    [#local envVariables = getFinalEnvironment(occurrence, _context ).Environment ]

    [#local role = (occurrence.Configuration.Settings.Product["Role"].Value)!""]

    [#local envContent = [
        "# hamlet provided env"
    ]]

    [#local envVariables += {
        "hamlet_request" : getCLORequestReference(),
        "hamlet_configuration" : getCLOConfigurationReference(),
        "hamlet_accountRegion" : accountRegionId,
        "hamlet_tenant" : tenantId,
        "hamlet_account" : accountId,
        "hamlet_product" : productId,
        "hamlet_region" : regionId,
        "hamlet_segment" : segmentId,
        "hamlet_environment" : environmentId,
        "hamlet_tier" : occurrence.Core.Tier.Id ,
        "hamlet_component" : occurrence.Core.Component.Id,
        "hamlet_credentials" : credentialsBucket,
        "hamlet_code" : codeBucket,
        "hamlet_logs" : operationsBucket,
        "hamlet_backups" : dataBucket
    }
    ]]

    [#list envVariables as key,value]
        [#local envContent +=
            [
                "[System.Environment]::SetEnvironmentVariable('${key}','${value}') ;"
            ]
        ]
    [/#list]

    [@computeTaskConfigSection
        computeTaskTypes=[ COMPUTE_TASK_HAMLET_ENVIRONMENT_VARIABLES ]
        id="HamletEnv"
        priority=2
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content={
                "files" : {
                    "c:\\ProgramData\\Hamlet\\Scripts\\set_dirs.ps1" : {
                        "content" : {
                            "Fn::Join" : [
                                "\n",
                                [
                                    "Start-Transcript -Path c:\\ProgramData\\Hamlet\\Logs\\setdirs.log ;",
                                    r'echo "Directory and File Creation" ;'
                                    r"mkdir c:\ProgramData\Hamlet\Logs\codeontap"
                                ]
                            ]
                        },
                        "mode" : "000755"
                    },
                    "c:\\ProgramData\\Hamlet\\Scripts\\set_env.ps1" : {
                        "content" : {
                            "Fn::Join" : [
                                "\n",
                                envContent
                            ]
                        },
                        "mode" : "000755"
                    },
                    "c:\\ProgramData\\Hamlet\\Scripts\\source_env.ps1" : {
                        "content" : {
                            "Fn::Join" : [
                                "\n",
                                [
                                    r"if (!(Test-Path $PsHome\profile.ps1)) {",
                                    r"   New-Item -Type file -Path $PROFILE.AllUsersAllHosts -Force ",
                                    r"}",
                                    r"Add-Content $PROFILE.AllUsersAllHosts '. c:\ProgramData\Hamlet\Scripts\set_env.ps1' "
                                ]
                            ]
                        },
                        "mode" : "000755"
                    }
                },
                "commands": {
                    "01Directories" : {
                        "command" : "powershell.exe -ExecutionPolicy Bypass -Command c:\\ProgramData\\Hamlet\\Scripts\\set_dirs.ps1",
                        "ignoreErrors" : false
                    },
                    "02SetEnv" : {
                        "command" : "powershell.exe -ExecutionPolicy Bypass -Command c:\\ProgramData\\Hamlet\\Scripts\\source_env.ps1",
                        "ignoreErrors" : false
                    }
                }
            }
    /]
[/#macro]
