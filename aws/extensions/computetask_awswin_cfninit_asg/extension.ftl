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
            "Start-Transcript -Path c:\\ProgramData\\Hamlet\\Logs\\user-data.log -Append ;",
            "echo 'Create staging dirs for cfninit scripts' ;",
            "mkdir c:\\ProgramData\\Hamlet\\Scripts ;",
            "mkdir c:\\Temp ;",
            "mkdir c:\\ProgramData\\Amazon\\AmazonCloudWatchAgent ;",
            "echo 'Remainder of configuration via metadata' ;",
            {
                "Fn::Sub" : [
                    r'cfn-init.exe -v --stack ${StackName} --resource ${Resource} --region ${Region} --configset ${ConfigSet} 2>&1 | Write-Output ',
                    {
                        "StackName" : { "Ref" : "AWS::StackName" },
                        "Region" : { "Ref" : "AWS::Region" },
                        "Resource" : computeResourceId,
                        "ConfigSet" : computeResourceId
                    }
                ]
            },
            ";",
            r'$init_status="$lastexitcode" ;',
            r'echo "Signal the status from cfn-init $init_status" ;',
            r'$instance_id="$(Invoke-WebRequest -UseBasicParsing -Uri http://169.254.169.254/latest/meta-data/instance-id)" ;',
            r'echo "Instance_id $instance_id" ;',
            r'Set-Location -Path "C:\Program Files\Amazon\AWSCLIV2" ;'
            {
                "Fn::Sub" : [
                    r'.\aws --region ${Region} autoscaling describe-auto-scaling-instances --instance-ids $instance_id --query AutoScalingInstances[0].AutoScalingGroupName --output text 2>&1 | Write-Output ',
                    {
                        "Region" : { "Ref" : "AWS::Region" }
                    }
                ]
            },
            ";",
            {
                "Fn::Sub" : [
                    r'.\aws --region ${Region} autoscaling describe-auto-scaling-instances --instance-ids $instance_id --query AutoScalingInstances[0].AutoScalingGroupName --output text | Tee-Object -Variable asg_name ',
                    {
                        "Region" : { "Ref" : "AWS::Region" }
                    }
                ]
            },
            ";",
            r'echo "Asg_name $asg_name" ;',
            {
                "Fn::Sub" : [
                    r'cfn-signal.exe -e $init_status --stack ${StackName} --resource ${Resource} --region ${Region} 2>&1 | Write-Output ',
                    {
                        "StackName" : { "Ref" : "AWS::StackName" },
                        "Region" : { "Ref" : "AWS::Region" },
                        "Resource" : computeResourceId
                    }
                ]
            },
            ";",
            r'echo "Signal the status to the ASG" ;',
            r'if ( "$init_status" -eq "0" )',
            r'{ ',
            r'   echo "init process successful"',
            r'   $asg_result="CONTINUE"',
            r'} else {',
            r'   echo "init process failed"',
            r'   $asg_result="ABANDON"',
            r'}',
            r'echo "Call params", $instance_id, $asg_name, $asg_result ;',
            {
                "Fn::Sub" : [
                    r'.\aws --region ${Region} autoscaling complete-lifecycle-action  --lifecycle-hook-name ${HookName} --auto-scaling-group-name $asg_name --instance-id $instance_id --lifecycle-action-result $asg_result 2>&1 | Write-Output ',
                    {
                        "Region" : { "Ref" : "AWS::Region" },
                        "HookName" : computeResourceId
                    }
                ]
            }
            ";",
            r'echo "exitcode from complete-lifecycle-action $lastexitcode" ;',
            r"</powershell>"
        ]
    /]

    [@computeTaskConfigSection
        computeTaskTypes=[ COMPUTE_TASK_AWS_CLI ]
        id="CFNHup"
        priority=1
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content={
            "files": {
                "c:\\cfn\\cfn-hup.conf" : {
                    "content" : { "Fn::Join" : ["", [
                    "[main]\n",
                    "stack=", { "Ref" : "AWS::StackName" }, "\n",
                    "region=", { "Ref" : "AWS::Region" }, "\n"
                    ]]}
                },
                "c:\\cfn\\hooks.d\\cfn-auto-reloader.conf" : {
                    "content": { "Fn::Join" : ["", [
                    "[cfn-auto-reloader-hook]\n",
                    "triggers=post.update\n",
                    "path=Resources.",
                        computeResourceId,
                        ".Metadata.AWS::CloudFormation::Init\n",
                    "action=cfn-init.exe ",
                        " -v -s ", { "Ref" : "AWS::StackName" },
                        " -r ", computeResourceId,
                        " --configsets ", computeResourceId,
                        " --region ", { "Ref" : "AWS::Region" }, "\n"
                    ]]}
                }
            },
            "services" : {
                "windows" : {
                    "cfn-hup" : {
                        "enabled" : "true",
                        "ensureRunning" : "true",
                        "files" : ["c:\\cfn\\cfn-hup.conf", "c:\\cfn\\hooks.d\\cfn-auto-reloader.conf"]
                    }
                }
            }
        }
    /]

[/#macro]
