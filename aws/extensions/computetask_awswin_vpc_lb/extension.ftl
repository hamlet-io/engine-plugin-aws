[#ftl]

[@addExtension
    id="computetask_awswin_vpc_lb"
    aliases=[
        "_computetask_awswin_vpc_lb"
    ]
    description=[
        "Uses the awscli to register with a vpc laod balancer"
    ]
    supportedTypes=[
        EC2_COMPONENT_TYPE,
        COMPUTECLUSTER_COMPONENT_TYPE
    ]
    scopes=[
        COMPUTETASK_EXTENSION_SCOPE
    ]
/]

[#macro shared_extension_computetask_awswin_vpc_lb_deployment_computetask occurrence ]

    [#local files = {}]
    [#local commands = {}]

    [#list _context.Links as linkId,linkTarget]

        [@debug message="Link Target" context=linkTarget enabled=false /]

        [#if !linkTarget?has_content]
            [#continue]
        [/#if]

        [#local linkTargetCore = linkTarget.Core ]
        [#local linkTargetConfiguration = linkTarget.Configuration ]
        [#local linkTargetResources = linkTarget.State.Resources ]
        [#local linkTargetAttributes = linkTarget.State.Attributes ]

        [#local sourceSecurityGroupIds = []]
        [#local sourceIPAddressGroups = [] ]

        [#switch linkTargetCore.Type]
            [#case LB_PORT_COMPONENT_TYPE]
            [#case LB_BACKEND_COMPONENT_TYPE]

                [#switch linkTargetAttributes["ENGINE"]]

                    [#case "application"]
                    [#case "network"]
                        [#local portId = linkTargetCore.Id ]
                        [#local targetGroupArn = linkTargetAttributes["TARGET_GROUP_ARN"]]

                        [#local scriptName = "register_targetgroup_${portId}" ]
                        [#local files += {
                            "c:\\ProgramData\\Hamlet\\Scripts\\${scriptName}.ps1" : {
                                "content" : {
                                    "Fn::Join" : [
                                        "\n",
                                        [
                                            "Start-Transcript -Path c:\\ProgramData\\Hamlet\\Logs\\${scriptName}.log",
                                            r'Set-Location -Path "C:\Program Files\Amazon\AWSCLIV2" ',
                                            {
                                                "Fn::Sub" : [
                                                    r'.\aws --region "${AWS::Region}" elbv2 register-targets --target-group-arn "${TargeGroupArn}" --targets "Id=$(Invoke-WebRequest -UseBasicParsing -Uri http://169.254.169.254/latest/meta-data/instance-id)" 2>&1 | Write-Output ',
                                                    { "TargeGroupArn": targetGroupArn }
                                                ]
                                            },
                                            "Stop-Transcript | out-null"
                                        ]
                                    ]
                                },
                                "mode" : "000755"
                            }
                        }]

                        [#local commands += {
                            scriptName : {
                                "command" : "powershell.exe -ExecutionPolicy Bypass -Command c:\\ProgramData\\Hamlet\\Scripts\\${scriptName}.ps1",
                                "ignoreErrors" : false
                            }
                        }]

                        [#break]

                    [#case "classic" ]
                        [#local lbId =  linkTargetAttributes["LB"] ]
                        [#local scriptName = "register_classiclb_${lbId}" ]

                        [#local files +=  {
                            "c:\\ProgramData\\Hamlet\\Scripts\\${scriptName}.ps1" : {
                                "content" : {
                                    "Fn::Join" : [
                                        "\n",
                                        [
                                            "Start-Transcript -Path c:\\ProgramData\\Hamlet\\Logs\\${scriptName}.log",
                                            r'Set-Location -Path "C:\Program Files\Amazon\AWSCLIV2" ',
                                            {
                                                "Fn::Sub" : [
                                                    r'.\aws --region "${AWS::Region}" elb register-instances-with-load-balancer --load-balancer-name "${LoadBalancer}" --instances "$(Invoke-WebRequest -UseBasicParsing -Uri http://169.254.169.254/latest/meta-data/instance-id)" 2>&1 | Write-Output ',
                                                    { "LoadBalancer": getReference(lbId) }
                                                ]
                                            }
                                        ]
                                    ]
                                },
                                "mode" : "000755"
                            }
                        }]
                        [#local commands += {
                            scriptName : {
                                "command" : "powershell.exe -ExecutionPolicy Bypass -Command c:\\ProgramData\\Hamlet\\Scripts\\${scriptName}.ps1",
                                "ignoreErrors" : false
                            }
                        }]

                        [#break]
                [/#switch]
                [#break]
        [/#switch]
    [/#list]

    [#local content = {}]
    [#if files?has_content || commands?has_content ]
        [#local content = {
            "files" : files,
            "commands" : commands
        }]
    [/#if]

    [@computeTaskConfigSection
        computeTaskTypes=[ COMPUTE_TASK_AWS_LB_REGISTRATION ]
        id="LoadBalancerRegistration"
        priority=8
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content=content
    /]
[/#macro]
