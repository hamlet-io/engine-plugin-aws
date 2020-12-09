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
                        "Id" : formatDependentResourceId(AWS_EFS_MOUNT_TARGET_RESOURCE_TYPE, id, zone.Id),
                        "Type" : AWS_EFS_MOUNT_TARGET_RESOURCE_TYPE
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
                "EFS" : getExistingReference(AWS_PROVIDER, id),
                "DIRECTORY" : "/"
            },
            "Roles" : {
                "Inbound" : {
                    "networkacl" : {
                        "SecurityGroups" : securityGroupId,
                        "Description" : core.FullName
                    }
                },
                "Outbound" : {
                    "default" : "root",
                    "write" : efsWritePermission(id),
                    "read" : efsReadPermission(id),
                    "root" : efsFullPermission(id),
                    "networkacl" : {
                        "Ports" : [ availablePorts ],
                        "SecurityGroups" : securityGroupId,
                        "Description" : core.FullName
                    }
                }
            }
        }
    ]
[/#macro]

[#macro aws_efsmount_cf_state occurrence parent={} ]
    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution]

    [#local efsId = parent.State.Resources["efs"].Id ]
    [#local accessPointId = formatResourceId(AWS_EFS_ACCESS_POINT_RESOURCE_TYPE, core.Id) ]

    [#local parentRoles = parent.State.Roles ]

    [#assign componentState =
        {
            "Resources" : {
                "accessPoint" :  {
                    "Id" : accessPointId,
                    "Name" : core.FullName,
                    "Type" : AWS_EFS_ACCESS_POINT_RESOURCE_TYPE
                }
            },
            "Attributes" : {
                "EFS" : getExistingReference(AWS_PROVIDER, efsId),
                "DIRECTORY" : (solution.chroot)?then(
                                    "/"
                                    solution.Directory
                                ),
                "ACCESS_POINT_ID": getExistingReference(AWS_PROVIDER, accessPointId),
                "ACCESS_POINT_ARN" : getExistingReference(AWS_PROVIDER, accessPointId, ARN_ATTRIBUTE_TYPE)
            },
            "Roles" : {
                "Inbound" : {
                    "networkacl" : parentRoles.Inbound["networkacl"]
                },
                "Outbound" : {
                    "default" : "root",
                    "write" : efsWritePermission(efsId, accessPointId),
                    "read" : efsReadPermission(efsId, accessPointId),
                    "root" : efsFullPermission(efsId, accessPointId),
                    "networkacl" : parentRoles.Outbound["networkacl"]
                }
            }
        }
    ]
[/#macro]
