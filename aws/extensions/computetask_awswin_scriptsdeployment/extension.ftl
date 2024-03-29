[#ftl]

[@addExtension
    id="computetask_awswin_scriptsdeployment"
    aliases=[
        "_computetask_awswin_scriptsdeployment"
    ]
    description=[
        "Runs a deployment from a scripts deployment"
    ]
    supportedTypes=[
        COMPUTECLUSTER_COMPONENT_TYPE
    ]
    scopes=[
        COMPUTETASK_EXTENSION_SCOPE
    ]
/]

[#macro shared_extension_computetask_awswin_scriptsdeployment_deployment_computetask occurrence ]

    [#local solution = occurrence.Configuration.Solution ]
    [#local scriptsFile = _context.ScriptsFile ]

    [#if scriptsFile?has_content ]

        [@computeTaskConfigSection
            computeTaskTypes=[ COMPUTE_TASK_RUN_SCRIPTS_DEPLOYMENT ]
            id="RunScriptsDeployment"
            priority=100
            engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
            content={
                "files" :{
                    "c:\\ProgramData\\Hamlet\\Scripts\\fetch_scripts.ps1" : {
                        "content" : {
                            "Fn::Join" : [
                                "\n",
                                [
                                    r'New-Item -Type Directory -Force c:\ProgramData\Hamlet\Scripts ;',
                                    r'Set-Location -Path "C:\Program Files\Amazon\AWSCLIV2" ;',
                                    {
                                        "Fn::Sub" : [
                                            r'.\aws s3 cp --quiet "${ScriptsFile}" c:\ProgramData\Hamlet\Scripts 2>&1 | Write-Output',
                                            {
                                                "Region" : {
                                                    "Ref" : "AWS::Region"
                                                },
                                                "ScriptsFile" : scriptsFile
                                            }
                                        ]
                                    },
                                    ";",
                                    r' if ( Test-Path "c:\ProgramData\Hamlet\Scripts\scripts.zip" -PathType leaf ) {',
                                    r'   Expand-Archive -Path "c:\ProgramData\Hamlet\Scripts\scripts.zip" -DestinationPath "c:\ProgramData\Hamlet\Scripts" ',
                                    r'} else {',
                                    r'   exit 1',
                                    r'}'
                                ]
                            ]
                        },
                        "mode" : "000755"
                    },
                    "c:\\ProgramData\\Hamlet\\Scripts\\run_scripts.ps1" : {
                        "content" : {
                            "Fn::Join" : [
                                "\n",
                                [
                                    r' if ( Test-Path "c:\ProgramData\Hamlet\Scripts\init.ps1" -PathType leaf ) {',
                                    r'    & "c:\ProgramData\Hamlet\Scripts\init.ps1" ',
                                    r' }'
                                ]
                            ]
                        },
                        "mode" : "000755"
                    }
                },
                "commands" : {
                    "01RunInitScript" : {
                        "command" : "powershell.exe -ExecutionPolicy Bypass -Command c:\\ProgramData\\Hamlet\\Scripts\\fetch_scripts.ps1",
                        "ignoreErrors" : false
                    },
                    "02RunInitScript" : {
                        "command" : "powershell.exe -ExecutionPolicy Bypass -Command c:\\ProgramData\\Hamlet\\Scripts\\run_scripts.ps1",
                        "cwd" : "c:\\ProgramData\\Hamlet\\Scripts\\",
                        "ignoreErrors" : false
                    }
                }
            }
        /]

    [#else]

        [@computeTaskConfigSection
            computeTaskTypes=[ COMPUTE_TASK_RUN_SCRIPTS_DEPLOYMENT ]
            id="SkipScriptsDeployment"
            priority=100
            engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
            content={}
        /]
    [/#if]
[/#macro]
