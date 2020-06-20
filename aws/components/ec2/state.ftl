[#ftl]

[#macro aws_ec2_cf_state occurrence parent={} ]
    [#local core = occurrence.Core ]
     [#local solution = occurrence.Configuration.Solution ]

    [#local zoneResources = {}]

    [#local securityGroupId = formatComponentSecurityGroupId(core.Tier, core.Component)]

    [#local availablePorts = [ "ssh" ]]
    [#list solution.Ports as id,port ]
        [#local availablePorts += [ port.Name ]]
    [/#list]

    [#list zones as zone ]
        [#local zoneResources +=
            { zone.Id : {
                "ec2Instance" : {
                    "Id"   : formatResourceId(AWS_EC2_INSTANCE_RESOURCE_TYPE, core.Id, zone.Id),
                    "Name" : formatName(tenantId, formatComponentFullName(core.Tier, core.Component), zone.Id),
                    "Type" : AWS_EC2_INSTANCE_RESOURCE_TYPE
                },
                "ec2ENI" : {
                    "Id" : formatResourceId(AWS_EC2_NETWORK_INTERFACE_RESOURCE_TYPE, core.Id, zone.Id, "eth0"),
                    "Type" : AWS_EC2_NETWORK_INTERFACE_RESOURCE_TYPE
                },
                "ec2EIP" : {
                    "Id" : getExistingReference(formatEIPId( core.Id, zone.Id))?has_content?then(
                        formatEIPId( core.Id, zone.Id),
                        formatEIPId( core.Id, zone.Id, "eth0")
                    ),
                    "Name" : formatName(core.FullName, zone.Name),
                    "Type" : AWS_EIP_RESOURCE_TYPE
                },
                "ec2EIPAssociation" : {
                    "Id" : formatEIPAssociationId( core.Id, zone.Id, "eth0"),
                    "Type" : AWS_EIP_ASSOCIATION_RESOURCE_TYPE
                }
            }}
        ]
    [/#list]

    [#assign componentState =
        {
            "Resources" : {
                "instanceProfile" : {
                    "Id" : formatEC2InstanceProfileId(core.Tier, core.Component),
                    "Type" : AWS_EC2_INSTANCE_PROFILE_RESOURCE_TYPE
                },
                "sg" : {
                    "Id" : securityGroupId,
                    "Ports" : availablePorts,
                    "Name" : core.FullName,
                    "Type" : AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE
                },
                "ec2Role" : {
                    "Id" : formatComponentRoleId(core.Tier, core.Component),
                    "Type" : AWS_IAM_ROLE_RESOURCE_TYPE,
                    "IncludeInDeploymentState" : false
                },
                "lg" : {
                    "Id" : formatLogGroupId(core.Id),
                    "Name" : core.FullAbsolutePath,
                    "Type" : AWS_CLOUDWATCH_LOG_GROUP_RESOURCE_TYPE,
                    "IncludeInDeploymentState" : false
                },
                "Zones" : zoneResources
            },
            "Attributes" : {
            },
            "Roles" : {
                "Inbound" : {
                    "networkacl" : {
                        "SecurityGroups" : getExistingReference(securityGroupId),
                        "Description" : core.FullName
                    }
                },
                "Outbound" : {
                    "networkacl" : {
                        "Ports" : [ availablePorts ],
                        "SecurityGroups" : getExistingReference(securityGroupId),
                        "Description" : core.FullName
                    }
                }
            }
        }
    ]
[/#macro]
