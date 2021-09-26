[#ftl]
[#macro aws_directory_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution ]

    [#local id = formatResourceId(AWS_DIRECTORY_RESOURCE_TYPE, core.Id) ]
    [#local securityGroupId = formatDependentSecurityGroupId(id)]

    [#local segmentSeedId = formatSegmentSeedId() ]
    [#local segmentSeed = getExistingReference(segmentSeedId)]

    [#local certificateObject = getCertificateObject(solution.Hostname!"")]
    [#local certificateDomains = getCertificateDomains(certificateObject) ]
    [#local primaryDomainObject = getCertificatePrimaryDomain(certificateObject) ]
    [#local hostName = getHostName(certificateObject, occurrence) ]
    [#local fqdn = formatDomainName(hostName, primaryDomainObject) ]

    [#local dnsPorts = [
        "dns-tcp", "dns-tcp",
        "globalcatalog",
        "kerebosauth88-tcp", "kerebosauth88-udp", "kerebosauth464-tcp", "kerebosauth464-udp",
        "ldap-tcp", "ldap-udp", "ldaps",
        "netlogin-tcp", "netlogin-udp",
        "ntp",
        "rpc", "ephemeralrpctcp", "ephemeralrpcudp",
        "rsync",
        "smb-tcp", "smb-udp",
        "anyicmp"
    ]]

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
                    "Name" : fqdn,
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
                "USERNAME" : solution.RootCredentials.Username,
                "IP_ADDRESSES" : getExistingReference(id, IP_ADDRESS_ATTRIBUTE_TYPE),
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
                        "Ports" : dnsPorts,
                        "SecurityGroups" : securityGroupId,
                        "Description" : core.FullName
                    }
                }
            }
        }
    ]
[/#macro]
