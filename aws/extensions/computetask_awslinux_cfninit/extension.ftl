[#ftl]

[@addExtension
    id="computetask_awslinux_cfninit"
    aliases=[
        "_computetask_awslinux_cfninit"
    ]
    description=[
        "Updates and runs the cfn init process based on the provided cfninit metadata"
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

[#macro shared_extension_computetask_awslinux_cfninit_deployment_computetask occurrence ]

    [#local computeResourceId = (_context.ComputeResourceId)!"" ]

    [@computeTaskConfigSection
        computeTaskTypes=[ COMPUTE_TASK_RUN_STARTUP_CONFIG, COMPUTE_TASK_AWS_CFN_SIGNAL ]
        id="CFNInit"
        priority=0
        engine=AWS_EC2_USERDATA_COMPUTE_TASK_CONFIG_TYPE
        content=[
            r'#!/bin/bash',
            r'set -uo pipefail',
            "exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1",
            "# Updat cfn bootstrap commands",
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
            "# Signal the status from cfn-init",
            {
                "Fn::Sub" : [
                    r'/opt/aws/bin/cfn-signal -e $? --stack ${StackName} --resource ${Resource} --region ${Region}',
                    {
                        "StackName" : { "Ref" : "AWS::StackName" },
                        "Region" : { "Ref" : "AWS::Region" },
                        "Resource" : computeResourceId
                    }
                ]
            }
        ]
    /]

[/#macro]
