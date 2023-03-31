[#ftl]

[#macro aws_es_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]

    [#if core.External!false]
        [#local esId = occurrence.State.Attributes["ES_DOMAIN_ARN"]!"HamletFatal: Could not find ARN" ]
        [#assign componentState =
            valueIfContent(
                {
                    "Resources" : {
                        "es" : {
                            "Id" : esId,
                            "Type" : AWS_ES_RESOURCE_TYPE,
                            "Deployed" : true
                        }
                    },
                    "Roles" : {
                        "Outbound" : {
                            "default" : "consume",
                            "consume" : esConsumePermission(esId),
                            "datafeed" : esKinesesStreamPermission(esId)
                        },
                        "Inbound" : {
                        }
                    }
                },
                esId,
                {}
            )
        ]

    [#else]

        [#local solution = occurrence.Configuration.Solution]
        [#local esId = formatResourceId(AWS_ES_RESOURCE_TYPE, core.Id)]

        [#local esSnapshotRoleId = formatDependentRoleId(esId, "snapshotStore" ) ]

        [#local baselineLinks = getBaselineLinks(occurrence, [ "AppData" ], true, false )]
        [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]

        [#local esHostName = getExistingReference(esId, DNS_ATTRIBUTE_TYPE) ]
        [#local certificateId = ""]
        [#local certificateRequired = false]

        [#local securityProfile = getSecurityProfile(occurrence, core.Type)]

        [#if isPresent(solution.Certificate) ]
            [#local certificateObject = getCertificateObject( solution.Certificate ) ]
            [#local hostName = getHostName(certificateObject, occurrence) ]
            [#local primaryDomainObject = getCertificatePrimaryDomain(certificateObject) ]
            [#local certificateId = formatDomainCertificateId(certificateObject, hostName) ]
            [#local esHostName = formatDomainName(hostName, primaryDomainObject) ]

            [#local certificateRequired = ["https-only", "http-https"]?seq_contains(securityProfile.ProtocolPolicy)]
        [/#if]

        [#local securityGroupId = formatSecurityGroupId(core.Id)]
        [#local availablePorts = []]

        [#switch (securityProfile.ProtocolPolicy)!"https-only" ]
            [#case "https-only" ]
                [#local availablePorts += [ "https" ] ]
                [#break]

            [#case "http-https" ]
                [#local availablePorts += [ "http", "https" ]]
                [#break]

            [#case "http-only" ]
                [#local availablePorts += [ "http"]]
                [#break]
        [/#switch]

        [#assign componentState =
            {
                "Resources" : {
                    "es" : {
                        "Id" : esId,
                        "Name" : core.ShortFullName,
                        "Type" : AWS_ES_RESOURCE_TYPE,
                        "Monitored" : true
                    } + 
                    attributeIfTrue(
                        "customHostName",
                        isPresent(solution.Certificate),
                        esHostName
                    ),
                    "servicerole" : {
                        "Id" : formatDependentRoleId(esId),
                        "Type" : AWS_IAM_ROLE_RESOURCE_TYPE,
                        "IncludeInDeploymentState" : false
                    },
                    "snapshotrole" : {
                        "Id" : esSnapshotRoleId,
                        "Type" : AWS_IAM_ROLE_RESOURCE_TYPE,
                        "IncludeInDeploymentState" : false
                    }
                } +
                attributeIfTrue(
                    "lg",
                    solution.Logging,
                    {
                        "Id" : formatLogGroupId(core.Id),
                        [#-- Include elasticsearch prefix for log policy alignment --]
                        "Name" : formatAbsolutePath("elasticsearch", core.FullAbsoluteRawPath),
                        "Type" : AWS_CLOUDWATCH_LOG_GROUP_RESOURCE_TYPE,
                        "IncludeInDeploymentState" : false
                    }
                ) +
                attributeIfTrue(
                    "sg",
                    solution.VPCAccess,
                    {
                        "Id" : formatSecurityGroupId(core.Id),
                        "Ports" : availablePorts,
                        "Name" : core.FullName,
                        "Type" : AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE
                    }
                ) +          
                attributeIfTrue(
                    "certificate",
                    certificateRequired,
                    {
                        "Id" : certificateId,
                        "Type" : AWS_CERTIFICATE_RESOURCE_TYPE,
                        "IncludeInDeploymentState" : false
                    }
                ),
                "Attributes" : {
                    "REGION" : getExistingReference(esId, REGION_ATTRIBUTE_TYPE)!getRegion(),
                    "AUTH" : solution.Authentication,
                    "FQDN" : esHostName,
                    "URL" : (securityProfile.ProtocolPolicy == "http-only")?then("http://", "https://") + esHostName,
                    "KIBANA_URL" : (securityProfile.ProtocolPolicy == "http-only")?then("http://", "https://") + esHostName + "/_plugin/kibana/",
                    "PORT" : 443,
                    "SNAPSHOT_ROLE_ARN" : getExistingReference(esSnapshotRoleId, ARN_ATTRIBUTE_TYPE),
                    "SNAPSHOT_BUCKET" : getExistingReference(baselineComponentIds["AppData"]!""),
                    "SNAPSHOT_PATH" : getAppDataFilePrefix(occurrence),
                    "INTERNAL_FQDN": getExistingReference(esId, DNS_ATTRIBUTE_TYPE)
                },
                "Roles" : {
                    "Outbound" : {
                        "default" : "consume",
                        "consume" : esConsumePermission(esId),
                        "datafeed" : esKinesesStreamPermission(esId),
                        "snapshot" : esConsumePermission(esId) +
                                        iamPassRolePermission(
                                            getExistingReference(esSnapshotRoleId, ARN_ATTRIBUTE_TYPE)
                                        )
                    } +
                    attributeIfTrue(
                        "networkacl",
                        solution.VPCAccess,
                        {
                            "Ports" : [ availablePorts ],
                            "SecurityGroups" : securityGroupId,
                            "Description" : core.FullName
                        }
                    ),
                    "Inbound" : {
                    } +
                    attributeIfTrue(
                        "networkacl",
                        solution.VPCAccess,
                        {
                            "SecurityGroups" : securityGroupId,
                            "Description" : core.FullName
                        }
                    )
                }
            }
        ]
    [/#if]
[/#macro]
