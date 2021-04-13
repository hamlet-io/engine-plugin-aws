[#ftl]

[#assign COMPUTE_TASK_AWS_CFN_SIGNAL = "aws_cfn_signal" ]
[@addComputeTask
    type=COMPUTE_TASK_AWS_CFN_SIGNAL
    properties=[
        {
            "Type" : "Description",
            "Value" : "Use cfn-signal to notify cloudformation of setup result"
        }
    ]
/]

[#assign COMPUTE_TASK_AWS_CLI = "aws_cli" ]
[@addComputeTask
    type=COMPUTE_TASK_AWS_CLI
    properties=[
        {
            "Type"  : "Description",
            "Value" : "Install the awscli"
        }
    ]
/]

[#assign COMPUTE_TASK_AWS_EIP = "aws_eip" ]
[@addComputeTask
    type=COMPUTE_TASK_AWS_EIP
    properties=[
        {
            "Type"  : "Description",
            "Value" : "Allocate an assigned elastic IP to the primary interface of the instance"
        }
    ]
/]

[#assign COMPUTE_TASK_AWS_ECS_AGENT_SETUP = "aws_ecs_setup" ]
[@addComputeTask
    type=COMPUTE_TASK_AWS_ECS_AGENT_SETUP
    properties=[
        {
            "Type" : "Description",
            "Value" : "Install and Configure the AWS ECS Agent for an Ec2 based ECS Instance"
        }
    ]
/]

[#assign COMPUTE_TASK_AWS_LB_REGISTRATION = "aws_lb_registration" ]
[@addComputeTask
    type=COMPUTE_TASK_AWS_LB_REGISTRATION
    properties=[
        {
            "Type" : "Description",
            "Value" : "Register the primary interface of an instance with vpc load balancers"
        }
    ]
/]
