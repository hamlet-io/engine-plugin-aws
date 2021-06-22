[#ftl]

[@addExtension
    id="computetask_awswin_cfninit_asg"
    aliases=[
        "_computetask_awswin_cfninit_asg"
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

[#macro shared_extension_computetask_awswin_cfninit_asg_deployment_computetask occurrence ]

    [#local computeResourceId = (_context.ComputeResourceId)!"" ]

    [@computeTaskConfigSection
        computeTaskTypes=[
            COMPUTE_TASK_RUN_STARTUP_CONFIG,
            COMPUTE_TASK_AWS_CFN_SIGNAL,
            COMPUTE_TASK_AWS_ASG_STARTUP_SIGNAL
        ]
        id="CFNInitASG"
        priority=0
        engine=AWS_EC2_USERDATA_COMPUTE_TASK_CONFIG_TYPE
        content=[
            r"<powershell>",
            "# 'Create logging dir for cfninit scripts' ;",
            "mkdir c:\\ProgramData\\Hamlet\\Logs\\hamlet_cfninit ;",
            "Start-Transcript -Path c:\\ProgramData\\Hamlet\\Logs\\hamlet_cfninit\\user-data.log -Append ;",
            "echo 'Create staging dirs for cfninit scripts' ;",
            "mkdir c:\\ProgramData\\Hamlet\\Scripts ;",
            "mkdir c:\\Temp ;",
            "mkdir c:\\ProgramData\\Amazon\\AmazonCloudWatchAgent ;",
            "echo 'Remainder of configuration via metadata' ;",
            {
                "Fn::Sub" : [
                    r'cfn-init.exe -v --stack ${StackName} --resource ${Resource} --region ${Region} --configset ${ConfigSet}',
                    {
                        "StackName" : { "Ref" : "AWS::StackName" },
                        "Region" : { "Ref" : "AWS::Region" },
                        "Resource" : computeResourceId,
                        "ConfigSet" : computeResourceId
                    }
                ]
            },
            r'$init_status=$lastexitcode ;',
            r'echo "Signal the status from cfn-init $init_status" ;',
            r'Start-Sleep 600 ;',
            ";",
            {
                "Fn::Sub" : [
                    r'cfn-signal.exe -e $init_status --stack ${StackName} --resource ${Resource} --region ${Region}',
                    {
                        "StackName" : { "Ref" : "AWS::StackName" },
                        "Region" : { "Ref" : "AWS::Region" },
                        "Resource" : computeResourceId
                    }
                ]
            },
            r'echo "Signal the status to the ASG" ;',
            r'$instance_id="$(Invoke-WebRequest -Uri http://169.254.169.254/latest/meta-data/instance-id)" ;',
            {
                "Fn::Sub" : [
                    r'$asg_name="$(aws --region ${Region} autoscaling describe-auto-scaling-instances --instance-ids "$instance_id" --query "AutoScalingInstances[0].AutoScalingGroupName" --output text)"',
                    {
                        "Region" : { "Ref" : "AWS::Region" }
                    }
                ]
            },
            r'if ( "$init_status" -eq "0" )',
            r'{ ',
            r'   echo "init process successful"',
            r'   $asg_result="CONTINUE"',
            r'} else {',
            r'   echo "init process failed"',
            r'   $asg_result="ABANDON"',
            r'}',
            {
                "Fn::Sub" : [
                    r'aws --region ${Region} autoscaling complete-lifecycle-action  --lifecycle-hook-name ${HookName} --auto-scaling-group-name $asg_name --instance-id $instance_id --lifecycle-action-result $asg_result ',
                    {
                        "Region" : { "Ref" : "AWS::Region" },
                        "HookName" : computeResourceId
                    }
                ]
            }
        ]
    /]

[/#macro]
