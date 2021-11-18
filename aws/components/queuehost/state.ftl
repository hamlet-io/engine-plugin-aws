[#ftl]
[#macro aws_queuehost_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution ]

    [#local id = formatResourceId(AWS_AMAZONMQ_BROKER_RESOURCE_TYPE, core.Id) ]
    [#local securityGroupId = formatDependentSecurityGroupId(id)]

    [#local ports = [ "rabbitmq", "https", "rabbitmq-ui" ]]

    [#local segmentSeedId = formatSegmentSeedId() ]
    [#local segmentSeed = getExistingReference(segmentSeedId)]

    [#local baselineLinks = getBaselineLinks(occurrence, [ "Encryption"] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]

    [#local cmkKeyId = baselineComponentIds["Encryption" ]]
    [#local secretLink = getLinkTarget(occurrence, solution.RootCredentials.Secret.Link, false)]

    [#local rootCredentialResources = getComponentSecretResources(
                                        occurrence,
                                        "root",
                                        "root",
                                        cmkKeyId,
                                        secretLink.Configuration.Solution.Engine,
                                        "Root credentials for broker"
                                    )]

    [#assign componentState =
        {
            "Resources" : {
                "broker" : {
                    "Id" : id,
                    "Name" : core.FullName,
                    "ShortName" : formatName( core.ShortFullName, segmentSeed)?truncate_c(50, ''),
                    "Type" : AWS_AMAZONMQ_BROKER_RESOURCE_TYPE,
                    "Ports" : ports,
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
                        "Ports" : ports,
                        "SecurityGroups" : securityGroupId,
                        "Description" : core.FullName
                    }
                }
            }
        }
    ]
[/#macro]
