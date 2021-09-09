[#ftl]
[#macro aws_directory_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution ]

    [#local id = formatResourceId(AWS_DIRECTORY_RESOURCE_TYPE, core.Id) ]
    [#local securityGroupId = formatDependentSecurityGroupId(id)]

    [#local segmentSeedId = formatSegmentSeedId() ]
    [#local segmentSeed = getExistingReference(segmentSeedId)]

    [#local rootCredentialResources = getComponentSecretResources(
                                        occurrence,
                                        "root",
                                        "root",
                                        "Root credentials for directory services"
                                    )]

    [#assign componentState =
        {
            "Resources" : {
                "directory" : {
                    "Id" : id,
                    "Name" : core.FullName,
                    "ShortName" : formatName( core.ShortFullName, segmentSeed)?truncate_c(50, ''),
                    "Type" : AWS_DIRECTORY_RESOURCE_TYPE,
                    "Monitored" : true
                },
                "sg" : {
                    "Id" : securityGroupId,
                    "Name" : core.FullName,
                    "Type" : AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE
                },
                "rootCredentials" : rootCredentialResources
            },
            "Attributes" : {
                "ENGINE" : solution.Engine,
                "URL" : getExistingReference(id, URL_ATTRIBUTE_TYPE)?ensure_starts_with(solution.RootCredentials.EncryptionScheme),
                "ENDPOINT" : getExistingReference(id, DNS_ATTRIBUTE_TYPE),
                "USERNAME" : solution.RootCredentials.Username,
                "PASSWORD" : getExistingReference(rootCredentialResources["secret"].Id, GENERATEDPASSWORD_ATTRIBUTE_TYPE)?ensure_starts_with(solution.RootCredentials.EncryptionScheme),
                "SECRET" : getExistingReference(rootCredentialResources["secret"].Id )
            },
            "Roles" : {
                "Inbound" : {
                    "networkacl" : {
                        "SecurityGroups" : securityGroupId,
                        "Description" : core.FullName
                    }
                },
                "Outbound" : {
                    "networkacl" : {
                        "Ports" : [ "ssh" ],
                        "SecurityGroups" : securityGroupId,
                        "Description" : core.FullName
                    }
                }
            }
        }
    ]
[/#macro]
