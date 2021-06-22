[#ftl]

[@addExtension
    id="computetask_awswin_eip"
    aliases=[
        "_computetask_awswin_eip"
    ]
    description=[
        "Uses the awscli to allocate an elastic ip"
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

[#macro shared_extension_computetask_awswin_eip_deployment_computetask occurrence ]

    [#local eips = _context.ElasticIPs ]
    [#local content = {}]

    [#if eips?has_content]
        [#local allocationIds = eips?map( eip -> getReference(eip, ALLOCATION_ATTRIBUTE_TYPE))]

        [#local script = [
            'Start-Transcript -Path c:\\ProgramData\\Hamlet\\Logs\\eip.log ;',
            'echo "Starting volume mount" ;',
            r'$instance_id="$(Invoke-WebRequest -Uri http://169.254.169.254/latest/meta-data/instance-id)" ;',
            { "Fn::Sub" : r'export AWS_DEFAULT_REGION="${AWS::Region}"' },
            {
                "Fn::Sub" : [
                    r'$available_eip="$(aws ec2 describe-addresses --filter "Name=allocation-id,Values=${AllocationIds}" --query ' + r"'Addresses[?AssociationId==`null`].AllocationId | [0]' " + '--output text )"',
                    { "AllocationIds": { "Fn::Join" : [ ",", allocationIds ] }}
                ]
            },
            r'if ( ("$available_eip" -eq "") -and ("$available_eip" -ne "None" )) {',
            r'  aws ec2 associate-address --instance-id $instance_id --allocation-id $available_eip --no-allow-reassociation',
            r'} else {',
            r'  echo "No elastic IP available to allocate"',
            r'  exit 255',
            r'}'
        ]]

        [#local content = {
            "files" : {
                "c:\\ProgramData\\Hamlet\\Scripts\\eip_allocation.ps1" : {
                    "content" : {
                        "Fn::Join" : [
                            "\n",
                            script
                        ]
                    },
                    "mode" : "000755"
                }
            },
            "commands" : {
                "01AssignEIP" : {
                    "command" : "c:\\ProgramData\\Hamlet\\Scripts\\eip_allocation.ps1",
                    "ignoreErrors" : false
                }
            }
        }]

    [/#if]


    [@computeTaskConfigSection
        computeTaskTypes=[ COMPUTE_TASK_AWS_EIP ]
        id="EIPAllocation"
        priority=3
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content=content
    /]
[/#macro]
