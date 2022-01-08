[#ftl]

[@addExtension
    id="runbook_get_ec2_ip"
    aliases=[
        "_runbook_get_ec2_ip"
    ]
    description=[
        "Run a boto3 command to return an ec2 IP address"
    ]
    supportedTypes=[
        RUNBOOK_STEP_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_runbook_get_ec2_ip_runbook_setup occurrence ]

    [#local aws_login_step =  (_context.DefaultEnvironment["AWS_LOGIN_STEP"])!"aws_login" ]
    [#local ec2_instance_id = (_context.DefaultEnvironment["ec2_instance_id"])!"__output:select_instance:result__" ]

    [#assign _context = mergeObjects(
        _context,
        {
            "TaskParameters" : {
                "Command" : [
                    "export AWS_ACCESS_KEY_ID='__output:${aws_login_step}:aws_access_key_id__'",
                    "export AWS_SECRET_ACCESS_KEY='__output:${aws_login_step}:aws_secret_access_key__'",
                    "export AWS_SESSION_TOKEN='__output:${aws_login_step}:aws_session_token__'",
                    r"python3 -c '" + r'import boto3; ec2=boto3.resource("ec2"); print(ec2.Instance("' + ec2_instance_id + r'").private_ip_address)' + r"'"
                ]?join("; ")
            }
        }
    )]
[/#macro]
