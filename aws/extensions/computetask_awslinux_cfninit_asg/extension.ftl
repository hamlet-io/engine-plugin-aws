[#ftl]

[@addExtension
    id="computetask_awslinux_cfninit_asg"
    aliases=[
        "_computetask_awslinux_cfninit_asg"
    ]
    description=[
        "Updates and runs the cfn init process based on the provided cfninit metadata and sends startup lifecycle event notification"
    ]
    supportedTypes=[
        ECS_COMPONENT_TYPE,
        COMPUTECLUSTER_COMPONENT_TYPE,
        BASTION_COMPONENT_TYPE
    ]
    scopes=[
        COMPUTETASK_EXTENSION_SCOPE
    ]
/]

[#macro shared_extension_computetask_awslinux_cfninit_asg_deployment_computetask occurrence ]

    [#local computeResourceId = (_context.ComputeResourceId)!"" ]

    [@computeTaskConfigSection
        computeTaskTypes=[
            COMPUTE_TASK_RUN_STARTUP_CONFIG,
            COMPUTE_TASK_AWS_CFN_SIGNAL
        ]
        id="CFNInitASG"
        priority=0
        engine=AWS_EC2_USERDATA_COMPUTE_TASK_CONFIG_TYPE
        content=[
            r'#!/bin/bash',
            r'set -uo pipefail',
            "exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1",
            "# Update cfn bootstrap commands",
            "yum install -y aws-cfn-bootstrap",
            "# Create staging dirs for cfninit scripts",
            "mkdir -p /var/log/hamlet_cfninit/",
            "mkdir -p /opt/hamlet_cfninit/",
            "# Remainder of configuration via metadata",
            {
                "Fn::Sub" : [
                    r'/opt/aws/bin/cfn-init -v --stack ${StackName} --resource ${Resource} --region ${Region} --configset ${ConfigSet}',
                    {
                        "StackName" : { "Ref" : "AWS::StackName" },
                        "Region" : { "Ref" : "AWS::Region" },
                        "Resource" : computeResourceId,
                        "ConfigSet" : computeResourceId
                    }
                ]
            },
            r'init_status=$?',
            "# Signal the status from cfn-init",
            {
                "Fn::Sub" : [
                    r'/opt/aws/bin/cfn-signal -e ${!init_status} --stack ${StackName} --resource ${Resource} --region ${Region}',
                    {
                        "StackName" : { "Ref" : "AWS::StackName" },
                        "Region" : { "Ref" : "AWS::Region" },
                        "Resource" : computeResourceId
                    }
                ]
            }
        ]
    /]

    [@computeTaskConfigSection
        computeTaskTypes=[ COMPUTE_TASK_AWS_CLI ]
        id="CFNHup"
        priority=1
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content={
            "files": {
                "/etc/cfn/cfn-hup.conf" : {
                    "content" : { "Fn::Join" : ["", [
                    "[main]\n",
                    "stack=", { "Ref" : "AWS::StackName" }, "\n",
                    "region=", { "Ref" : "AWS::Region" }, "\n"
                    ]]}
                },
                "/etc/cfn/hooks.d/cfn-auto-reloader.conf" : {
                    "content": {
                        "Fn::Join" : [
                            "\n",
                            [
                                "[cfn-auto-reloader-hook]",
                                "triggers=post.update",
                                {
                                    "Fn::Sub" : [
                                        r'path=Resources.${Resource}.Metadata.AWS::CloudFormation::Init',
                                        {
                                            "Resource" : computeResourceId
                                        }
                                    ]
                                },
                                {
                                    "Fn::Sub" : [
                                        r'action=/opt/aws/bin/cfn-init -v -s ${StackName} -r ${Resource} --configsets ${Resource} --region ${Region}',
                                        {
                                            "StackName" : { "Ref" : "AWS::StackName" },
                                            "Region" : { "Ref" : "AWS::Region" },
                                            "Resource" : computeResourceId
                                        }
                                    ]
                                },
                                "runas=root",
                                ""
                            ]
                        ]
                    },
                    "mode"  : "000400",
                    "owner" : "root",
                    "group" : "root"
                }
            },
            "services" : {
                "sysvinit" : {
                    "cfn-hup" : {
                        "enabled" : "true",
                        "ensureRunning" : "true",
                        "files" : [
                            "/etc/cfn/cfn-hup.conf",
                            "/etc/cfn/hooks.d/cfn-auto-reloader.conf"
                        ]
                    }
                }
            }
        }
    /]


    [#local asg_signal_script = [
        r'#!/bin/bash',
        r'set -euo pipefail',
        r'exec > >(tee /var/log/hamlet_cfninit/asg_signal.log | logger -t codeontap-asg-signal -s 2>/dev/console) 2>&1',
        r'# Signal the status to the ASG',
        r'instance_id="$(curl http://169.254.169.254/latest/meta-data/instance-id)"',
        {
            "Fn::Sub": [
                r'region="${Region}"',
                {
                    "Region" : { "Ref" : "AWS::Region" }
                }
            ]
        },
        {
            "Fn::Sub": [
                r'hook_name="${HookName}"',
                {
                    "HookName" : computeResourceId
                }
            ]
        },
        r'asg_name="$(aws --region ${region} autoscaling describe-auto-scaling-instances --instance-ids "${instance_id}" --query "AutoScalingInstances[0].AutoScalingGroupName" --output text)"',
        r'lifecycle_state="$(aws --region ${region} autoscaling describe-auto-scaling-instances --instance-ids "${instance_id}" --query "AutoScalingInstances[0].LifecycleState" --output text)"',
        r'if [[ "${lifecycle_state}" != "InService" ]]; then',
        r'  aws --region ${region} autoscaling complete-lifecycle-action  --lifecycle-hook-name ${hook_name} --auto-scaling-group-name ${asg_name} --instance-id ${instance_id} --lifecycle-action-result CONTINUE',
        r'else',
        r'  echo "Already in service"',
        r'fi'
    ]]


    [@computeTaskConfigSection
        computeTaskTypes=[
            COMPUTE_TASK_AWS_ASG_STARTUP_SIGNAL
        ]
        id="ASGLifecycleSignal"
        priority=999
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content={
            "files" : {
                "/opt/hamlet_cfninit/signal_asg_lifecycle.sh" : {
                    "content" : {
                        "Fn::Join" : [
                            "\n",
                            asg_signal_script
                        ]
                    },
                    "mode" : "000755"
                }
            },
            "commands" : {
                "SignalASG" : {
                    "command" : "/opt/hamlet_cfninit/signal_asg_lifecycle.sh",
                    "ignoreErrors" : false
                }
            }
        }
    /]

[/#macro]
