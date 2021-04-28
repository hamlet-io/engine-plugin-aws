[#ftl]

[@addExtension
    id="computetask_awslinux_vpc_lb"
    aliases=[
        "_computetask_awslinux_vpc_lb"
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

[#macro shared_extension_computetask_awslinux_vpc_lb_deployment_computetask occurrence ]

    [#local files = {}]
    [#local commands = {}]

    [#list _context.Links as linkId,link]
        [#local linkTarget = getLinkTarget(occurrence, link) ]

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

                [#switch linkTargetAttributes["ENGINE"]]

                    [#case "application"]
                    [#case "network"]
                        [#local configSets += getInitConfigLBTargetRegistration(linkTargetCore.Id, linkTargetAttributes["TARGET_GROUP_ARN"])]

                        [#local portid = linkTargetCore.Id ]
                        [#local targetGroupArn = linkTargetAttributes["TARGET_GROUP_ARN"]]

                        [#local scriptName = "register_targetgroup_${portId}" ]
                        [#local files += {
                            "/opt/hamlet_cfninit/${scriptName}.sh" : {
                                "content" : {
                                    "Fn::Join" : [
                                        "\n",
                                        [
                                            r'#!/bin/bash',
                                            r'set -euo pipefail',
                                            'exec > >(tee /var/log/hamlet_cfninit/${scriptName}.log | logger -t ${scriptName} -s 2>/dev/console) 2>&1',
                                            {
                                                "Fn::Sub" : [
                                                    r'aws --region "${AWS::Region}" elbv2 register-targets --target-group-arn "${TargeGroupArn}" --targets "Id=$(curl http://169.254.169.254/latest/meta-data/instance-id)"',
                                                    { "TargeGroupArn": targetGroupArn }
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
                                "command" : "/opt/hamlet_cfninit/${scriptName}.sh",
                                "ignoreErrors" : false
                            }
                        }]

                        [#break]

                    [#case "classic" ]
                        [#local lbId =  linkTargetAttributes["LB"] ]
                        [#local scriptName = "register_classiclb_${lbId}" ]

                        [#local files +=  {
                            "/opt/hamlet_cfninit/${scriptName}.sh" : {
                                "content" : {
                                    "Fn::Join" : [
                                        "\n",
                                        [
                                            r'#!/bin/bash',
                                            r'set -euo pipefail',
                                            'exec > >(tee /var/log/hamlet_cfninit/${scriptName}.log | logger -t ${scriptName} -s 2>/dev/console) 2>&1',
                                            {
                                                "Fn::Sub" : [
                                                    r'aws --region "${AWS::Region}" elb register-instances-with-load-balancer --load-balancer-name "${LoadBalancer}" --instances "$(curl http://169.254.169.254/latest/meta-data/instance-id)"',
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
                                "command" : "/opt/hamlet_cfninit/${scriptName}.sh",
                                "ignoreErrors" : false
                            }
                        }]

                        [#break]
                [/#switch]
                [#break]
        [/#switch]
    [/#list]

    [#local content = {}]
    [#if files?has_content && commands?has_content ]
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
