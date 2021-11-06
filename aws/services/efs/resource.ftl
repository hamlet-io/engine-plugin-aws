[#ftl]

[#assign EFS_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[#assign EFS_MOUNT_TARGET_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[#assign EFS_ACCESS_POINT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "Attribute" : "Arn"
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_EFS_RESOURCE_TYPE
    mappings=EFS_OUTPUT_MAPPINGS
/]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_EFS_MOUNT_TARGET_RESOURCE_TYPE
    mappings=EFS_MOUNT_TARGET_MAPPINGS
/]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_EFS_ACCESS_POINT_RESOURCE_TYPE
    mappings=EFS_ACCESS_POINT_MAPPINGS
/]

[#macro createEFS id tags encrypted kmsKeyId iamRequired=true resourcePolicyStatements=[] dependencies=[]  ]
    [@cfResource
        id=id
        type="AWS::EFS::FileSystem"
        properties=
            {
                "PerformanceMode" : "generalPurpose",
                "FileSystemTags" : tags
            } +
            encrypted?then(
                {
                    "Encrypted" : true,
                    "KmsKeyId" : getReference(kmsKeyId, ARN_ATTRIBUTE_TYPE)
                },
                {}
            ) +
            attributeIfTrue(
                "FileSystemPolicy",
                iamRequired,
                getPolicyDocumentContent(resourcePolicyStatements)
            )
        outputs=EFS_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]

[#macro createEFSMountTarget id efsId subnet securityGroups type="NFS" dependencies="" ]
    [#switch type]
        [#case "NFS"]
            [@cfResource
                id=id
                type="AWS::EFS::MountTarget"
                properties=
                    {
                        "SubnetId" : subnet?is_enumerable?then(
                                        subnet[0],
                                        subnet
                        ),
                        "FileSystemId" : getReference(efsId),
                        "SecurityGroups": getReferences(securityGroups)
                    }
                outputs=EFS_MOUNT_TARGET_MAPPINGS
                dependencies=dependencies
            /]
        [#break]
        [#case "FSX-WIN"]
            [#-- Not required for this type --]
        [#break]
        [#case "FSX-LUSTRE"]
            [#-- Not required for this type --]
        [#break]
    [/#switch]
[/#macro]

[#macro createEFSAccessPoint id efsId tags
        overidePermissions=false
        type="NFS"
        chroot=false
        uid=""
        gid=""
        secondaryGids=""
        permissions=""
        rootPath=""
    ]

    [#switch type]
        [#case "NFS"]
            [@cfResource
                id=id
                type="AWS::EFS::AccessPoint"
                properties=
                    {
                        "FileSystemId" : getReference(efsId),
                        "AccessPointTags" : tags
                    } +
                    attributeIfTrue(
                        "PosixUser",
                        overidePermissions,
                        {
                            "Uid" : uid,
                            "Gid" : gid
                        } +
                        attributeIfContent(
                            "SecondaryGids",
                            secondaryGids
                        )
                    ) +
                    attributeIfTrue(
                        "RootDirectory",
                        chroot,
                        {
                            "CreationInfo" : {
                                "OwnerUid" : uid,
                                "OwnerGid" : gid,
                                "Permissions" : permissions
                            },
                            "Path" : rootPath?remove_ending("/")?ensure_starts_with("/")
                        }
                    )
                outputs=EFS_ACCESS_POINT_MAPPINGS
                dependencies=dependencies
            /]
        [#break]
        [#case "FSX-WIN"]

        [#break]
        [#case "FSX-LUSTRE"]

        [#break]
    [/#switch]
[/#macro]
