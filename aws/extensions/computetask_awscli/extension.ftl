[#ftl]

[@addExtension
    id="computetask_awscli"
    aliases=[
        "_computetask_awscli"
    ]
    description=[
        "Installs the awscli"
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

[#macro shared_extension_computetask_awscli_deployment_computetask occurrence ]

    [#local solution = occurrence.Configuration.Solution ]
    [#local operatingSystem = solution.ComputeInstance.OperatingSystem]

    [#local content = {}]
    [#switch operatingSystem.Family ]
        [#case "windows" ]
            [#switch operatingSystem.Distribution ]
                [#case "awswin" ]
                    [#local content = {
                        "packages" : {
                            "msi" : {
                                "awscli" : "https://awscli.amazonaws.com/AWSCLIV2.msi"
                            }
                        }
                    }]
                    [#break]
            [/#switch]
        [#break]

        [#case "linux" ]
            [#switch operatingSystem.Distribution ]
                [#case "awslinux" ]
                    [#switch operatingSystem.MajorVersion ]
                        [#case "2"]
                            [#local content = {
                                "packages" : {
                                    "yum" : {
                                        "awscli" : []
                                    }
                                }
                            }]
                            [#break]
                        [#case "1" ]
                            [#local content = {
                                "packages" : {
                                    "yum" : {
                                        "aws-cli" : []
                                    }
                                }
                            }]
                            [#break]
                    [/#switch]
                    [#break]
            [/#switch]
            [#break]
        [#break]
    [/#switch]

    [#if ! (content?has_content) ]
        [@fatal
            message="computetask_awscli could not find a way to install the aws cli for this os"
            detail="Check your operating system config or replace this extension with your own"
            context={ "OccurrenceId" : core.Id, "OperatingSystem" : operatingSystem }
        /]
    [/#if]

    [@computeTaskConfigSection
        computeTaskTypes=[ COMPUTE_TASK_AWS_CLI ]
        id="AWSClI"
        priority=1
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content=content
    /]

[/#macro]
