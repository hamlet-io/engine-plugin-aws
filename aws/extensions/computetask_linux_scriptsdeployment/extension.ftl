[#ftl]

[@addExtension
    id="computetask_linux_scriptsdeployment"
    aliases=[
        "_computetask_linux_scriptsdeployment"
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

[#macro shared_extension_computetask_linux_scriptsdeployment_deployment_computetask occurrence ]

    [#local solution = occurrence.Configuration.Solution ]
    [#local scriptsFile = _context.ScriptsFile ]
    [#local envVariables = getFinalEnvironment(occurrence, _context).Environment ]
    [#local shutDownOnCompletion=solution.UseInitAsService ]

    [@computeTaskConfigSection
        computeTaskTypes=[ COMPUTE_TASK_RUN_SCRIPTS_DEPLOYMENT ]
        id="RunScriptsDeployment"
        priority=100
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content={
            "packages" : {
                "yum" : {
                    "aws-cli" : [],
                    "unzip" : []
                }
            },
            "files" :{
                "/opt/hamlet_cfninit/fetch_scripts.sh" : {
                    "content" : {
                        "Fn::Join" : [
                            "\n",
                            [
                                r'#!/bin/bash -ex',
                                r'exec > >(tee /var/log/hamlet_cfninit/fetch-scripts.log | logger -t codeontap-scripts-fetch -s 2>/dev/console) 2>&1',
                                {
                                    "Fn::Sub" : [
                                        r'aws --region "${Region}" s3 cp --quiet "s3://${ScriptsFile}" /opt/hamlet/scripts',
                                        {
                                            "Region" : { "Fn::Ref" : "AWS::Region" },
                                            "ScriptsFile" : scriptsFile
                                        }
                                    ]
                                },
                                r' if [[ -f /opt/hamlet/scripts/scripts.zip ]]; then',
                                r'unzip /opt/hamlet/scripts/scripts.zip -d /opt/hamlet/scripts/',
                                r'chmod -R 0544 /opt/hamlet/scripts/',
                                r'else',
                                r'exit 1',
                                r'fi'
                            ]
                        ]
                    },
                    "mode" : "000755"
                },
                "/opt/hamlet_cfninit/run_scripts.sh" : {
                    "content" : {
                        "Fn::Join" : [
                            "\n",
                            [
                                r'#!/bin/bash -ex',
                                r'exec > >(tee /var/log/hamlet_cfninit/fetch.log|logger -t codeontap-scripts-init -s 2>/dev/console) 2>&1',
                                r'[ -f /opt/hamlet/scripts/init.sh ] &&  /opt/hamlet/scripts/init.sh'
                            ]
                        ]
                    },
                    "mode" : "000755"
                }
            },
            "commands" : {
                "01RunInitScript" : {
                    "command" : "/opt/hamlet_cfninit/fetch_scripts.sh",
                    "ignoreErrors" : false
                },
                "02RunInitScript" : {
                    "command" : "/opt/hamlet_cfninit/run_scripts.sh",
                    "cwd" : "/opt/hamlet/scripts/",
                    "ignoreErrors" : false
                } +
                attributeIfContent(
                    "env",
                    envVariables,
                    envVariables
                )
            } + shutDownOnCompletion?then(
                {
                    "03ShutDownInstance" : {
                        "command" : "shutdown -P +10",
                        "ignoreErrors" : false
                    }
                },
                {}
            )
        }
    /]
[/#macro]
