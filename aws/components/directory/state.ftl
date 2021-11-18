[#ftl]
[#macro aws_directory_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution ]

    [#local segmentSeedId = formatSegmentSeedId() ]
    [#local segmentSeed = getExistingReference(segmentSeedId)]

    [#local certificateObject = getCertificateObject(solution.Hostname!"")]
    [#local certificateDomains = getCertificateDomains(certificateObject) ]
    [#local primaryDomainObject = getCertificatePrimaryDomain(certificateObject) ]
    [#local hostName = getHostName(certificateObject, occurrence) ]
    [#local fqdn = formatDomainName(hostName, primaryDomainObject) ]

    [#local adminUser = solution.RootCredentials.Username ]

    [#local dnsPorts = [
        "dns-tcp", "dns-tcp", "globalcatalog",
        "kerebosauth88-tcp", "kerebosauth88-udp", "kerebosauth464-tcp", "kerebosauth464-udp",
        "ldap-tcp", "ldap-udp", "ldaps", "netlogin-tcp", "netlogin-udp", "ntp",
        "rpc", "ephemeralrpctcp", "ephemeralrpcudp", "rsync",
        "smb-tcp", "smb-udp", "anyicmp"
    ]]

    [#local resources = {}]
    [#local attributes = {
        "ENGINE" : solution.Engine,
        "DOMAIN_NAME" : fqdn
    }]

    [#if solution.RootCredentials.Secret.Source == "generated" ]

        [#local baselineLinks = getBaselineLinks(occurrence, [ "Encryption"] )]
        [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]

        [#local cmkKeyId = baselineComponentIds["Encryption" ]]
        [#local secretLink = getLinkTarget(occurrence, solution.RootCredentials.Secret.Link, false)]

        [#local resources = mergeObjects(
                    resources,
                    {
                        "rootCredentials" : getComponentSecretResources(
                                                occurrence,
                                                "Admin",
                                                "Admin",
                                                cmkKeyId,
                                                secretLink.Configuration.Solution.Engine,
                                                "Admin credentials for directory services"
                                            )
                    }
                )]

        [#local attributes = mergeObjects(
                    attributes,
                    {
                        "USERNAME" : adminUser,
                        "PASSWORD" : getExistingReference(resources["rootCredentials"]["secret"].Id, GENERATEDPASSWORD_ATTRIBUTE_TYPE)?ensure_starts_with(solution.RootCredentials.EncryptionScheme),
                        "SECRET" : getExistingReference(resources["rootCredentials"]["secret"].Id )
                    }
                )]
    [/#if]

    [#switch solution.Engine ]
        [#case "ActiveDirectory"]
        [#case "Simple"]

            [#local id = formatResourceId(AWS_DIRECTORY_RESOURCE_TYPE, core.Id) ]
            [#local securityGroupId = formatDependentSecurityGroupId(id)]

            [#local resources = mergeObjects(
                    resources,
                    {
                        "directory" : {
                            "Id" : id,
                            "Name" : fqdn,
                            "ShortName" : formatName( core.ShortFullName, segmentSeed)?truncate_c(50, ''),
                            "Username" : adminUser,
                            "Type" : AWS_DIRECTORY_RESOURCE_TYPE,
                            "Monitored" : true
                        },
                        "sg" : {
                            "Id" : securityGroupId,
                            "Name" : core.FullName,
                            "Type" : AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE
                        }
                    }
            )]

            [#local networkLink = getOccurrenceNetwork(occurrence).Link!{} ]
            [#local networkLinkTarget = getLinkTarget(occurrence, networkLink ) ]
            [#local providerDNS = (networkLinkTarget.Configuration.Solution.DNS.UseProvider)!true ]

            [#if providerDNS ]
                [#local resources = mergeObjects(
                    resources,
                    {
                        "resolver" : {
                            "endpoint" : {
                                "Id" : formatResourceId(AWS_ROUTE53_RESOLVER_ENDPOINT_RESOURCE_TYPE, core.Id),
                                "Name" : core.FullName,
                                "Type" : AWS_ROUTE53_RESOLVER_ENDPOINT_RESOURCE_TYPE
                            },
                            "rule" : {
                                "Id" : formatResourceId(AWS_ROUTE53_RESOLVER_RULE_RESOURCE_TYPE, core.Id),
                                "Name" : core.FullName,
                                "Type" : AWS_ROUTE53_RESOLVER_RULE_RESOURCE_TYPE
                            },
                            "association" : {
                                "Id" : formatResourceId(AWS_ROUTE53_RESOLVER_RULE_ASSOC_RESOURCE_TYPE, core.Id),
                                "Name" : core.FullName,
                                "Type" : AWS_ROUTE53_RESOLVER_RULE_ASSOC_RESOURCE_TYPE
                            },
                            "sg" : {
                                "Id" : formatResourceId(AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE, core.Id),
                                "Name" : core.FullName,
                                "Type" : AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE
                            }
                        }
                    }
                )]
            [/#if]

            [#local attributes = mergeObjects(
                        attributes,
                        {
                            "IP_ADDRESSES" : getExistingReference(id, IP_ADDRESS_ATTRIBUTE_TYPE),
                            "DOMAIN_ID" : getExistingReference(id),
                            "FQDN" : fqdn
                        }
            )]
            [#break]

        [#case "aws:ADConnector" ]

            [#local id = formatResourceId(AWS_DS_AD_CONNECTOR_RESOURCE_TYPE, core.Id) ]
            [#local securityGroupId = formatDependentSecurityGroupId(id)]

            [#local resources = mergeObjects(
                    resources,
                    {
                        "connector": {
                            "Id" : id,
                            "Name" : core.FullName,
                            "Type" : AWS_DS_AD_CONNECTOR_RESOURCE_TYPE,
                            "DomainName" : fqdn,
                            "Monitored" : true
                        },
                        "sg" : {
                            "Id" : securityGroupId,
                            "Name" : core.FullName,
                            "Type" : AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE
                        }
                    }
            )]

            [#local attributes = mergeObjects(
                attributes,
                {
                    "DOMAIN_ID" : getExistingReference(id),
                    "FQDN" : fqdn
                }
            )]
            [#break]
    [/#switch]

    [#assign componentState =
        {
            "Resources" : resources,
            "Attributes" : attributes,
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
