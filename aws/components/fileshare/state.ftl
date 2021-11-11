[#ftl]

[#macro aws_fileshare_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local id = ""]
    [#local resources = {}]
    [#local zoneResources = {} ]

    [#switch solution.Engine ]
        [#case "NFS"]
            [#local id = formatResourceId(AWS_EFS_RESOURCE_TYPE, core.Id)]
            [#local securityGroupId = formatDependentSecurityGroupId(id) ]
            [#local availablePorts = [ "nfs" ]]

            [#local resources = mergeObjects(
                        resources,
                        {
                            "efs" : {
                                "Id" : id,
                                "Name" : core.FullName,
                                "Type" : AWS_EFS_RESOURCE_TYPE
                            },
                            "sg" : {
                                "Id" : securityGroupId,
                                "Ports" : availablePorts,
                                "Name" : core.FullName,
                                "Type" : AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE
                            }
                        }
            )]

            [#list getZones() as zone ]
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

            [#break]

        [#case "SMB"]
            [#local id = formatResourceId(AWS_FSX_FILESYSTEM_RESOURCE_TYPE, core.Id)]
            [#local securityGroupId = formatDependentSecurityGroupId(id) ]

            [#local availablePorts = [ "smb-tcp", "smb-udp", "winrm" ]]

            [#local resources = mergeObjects(
                        resources,
                        {
                            "fsx" :  {
                                "Id" : id,
                                "Name" : core.FullName,
                                "Type" : AWS_FSX_FILESYSTEM_RESOURCE_TYPE
                            },
                            "sg" : {
                                "Id" : securityGroupId,
                                "Ports" : availablePorts,
                                "Name" : core.FullName,
                                "Type" : AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE
                            }
                        }
            )]
            [#break]
    [/#switch]

    [#assign componentState =
        {
            "Resources" : resources +
            attributeIfContent(
                "Zones",
                zoneResources
            ),
            "Attributes" : {
                "EFS" : getExistingReference(id),
                "FILESHARE_ID" : getExistingReference(id),
                "DIRECTORY" : "/"
            } +
            attributeIfTrue(
                "EFS",
                (solution.Engine == "NFS"),
                getExistingReference(id)
            ) +
            attributeIfTrue(
                "HOSTNAME",
                (solution.Engine == "SMB"),
                getExistingReference(id, DNS_ATTRIBUTE_TYPE)
            ),
            "Roles" : {
                "Inbound" : {
                    "networkacl" : {
                        "SecurityGroups" : securityGroupId,
                        "Description" : core.FullName
                    }
                },
                "Outbound" : {
                    "networkacl" : {
                        "Ports" : [ availablePorts ],
                        "SecurityGroups" : securityGroupId,
                        "Description" : core.FullName
                    }
                } +
                (solution.Engine == "NFS")?then(
                    {
                        "default" : "root",
                        "write" : efsWritePermission(id),
                        "read" : efsReadPermission(id),
                        "root" : efsFullPermission(id)
                    },
                    {}
                )
            }
        }
    ]
[/#macro]

[#macro aws_filesharemount_cf_state occurrence parent={} ]
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
                "EFS" : getExistingReference(efsId),
                "DIRECTORY" : (solution.chroot)?then(
                                    "/"
                                    solution.Directory
                                ),
                "ACCESS_POINT_ID": getExistingReference(accessPointId),
                "ACCESS_POINT_ARN" : getExistingReference(accessPointId, ARN_ATTRIBUTE_TYPE)
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
