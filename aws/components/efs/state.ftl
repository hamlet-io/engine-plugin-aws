[#ftl]

[#macro aws_efs_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]

    [#local id = formatEFSId( core.Tier, core.Component, occurrence) ]

    [#local securityGroupId = formatDependentSecurityGroupId(id) ]
    [#local availablePorts = [ "nfs" ]]

    [#local zoneResources = {} ]
    [#list zones as zone ]
        [#local zoneResources +=
            {
                zone.Id : {
                    "efsMountTarget" : {
                        "Id" : formatDependentResourceId(AWS_EFS_MOUNTTARGET_RESOURCE_TYPE, id, zone.Id),
                        "Type" : AWS_EFS_MOUNTTARGET_RESOURCE_TYPE
                    }
                }
            }
        ]
    [/#list]

    [#assign componentState =
        {
            "Resources" : {
                "efs" : {
                    "Id" : id,
                    "Name" : formatComponentFullName(core.Tier, core.Component, occurrence),
                    "Type" : AWS_EFS_RESOURCE_TYPE
                },
                "sg" : {
                    "Id" : securityGroupId,
                    "Ports" : availablePorts,
                    "Name" : core.FullName,
                    "Type" : AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE
                },
                "Zones" : zoneResources
            },
            "Attributes" : {
                "EFS" : getExistingReference(id)
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

[#macro aws_efsmount_cf_state occurrence parent={} ]
    [#local configuration = occurrence.Configuration.Solution]

    [#local efsId = parent.State.Attributes["EFS"] ]

    [#local parentRoles = parent.State.Roles ]

    [#assign componentState =
        {
            "Resources" : {},
            "Attributes" : {
                "EFS" : efsId,
                "DIRECTORY" : configuration.Directory
            },
            "Roles" : {
                "Inbound" : {
                    "networkacl" : parentRoles.Inbound["networkacl"]
                },
                "Outbound" : {
                    "networkacl" : parentRoles.Outbound["networkacl"]
                }
            }
        }
    ]
[/#macro]
