[#ftl]

[#macro aws_filetransfer_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local fileServerId = formatResourceId(AWS_TRANSFER_SERVER_RESOURCE_TYPE, core.Id)]

    [#if isPresent(solution.Certificate) ]
        [#local certificateObject = getCertificateObject(solution.Certificate, segmentQualifiers ) ]

        [#local hostName = getHostName(certificateObject, occurrence) ]
        [#local primaryDomainObject = getCertificatePrimaryDomain(certificateObject) ]

        [#local fqdn = formatDomainName(hostName, primaryDomainObject) ]
    [#else]
        [#local fqdn = "${getExistingReference(fileServerId)}.server.transfer.${regionId}.amazonaws.com"]
    [/#if]

    [#local occurrenceNetwork = getOccurrenceNetwork(occurrence) ]
    [#local networkLink = occurrenceNetwork.Link!{} ]

    [#local routeTableLinkTarget = getLinkTarget(occurrence, networkLink + { "RouteTable" : occurrenceNetwork.RouteTable })]
    [#local routeTableConfiguration = routeTableLinkTarget.Configuration.Solution ]
    [#local publicRouteTable = routeTableConfiguration.Public ]

    [#local securityGroupId = formatDependentSecurityGroupId(fileServerId) ]
    [#local availablePorts = [ "ssh" ]]

    [#local zoneResources = {}]

    [#if publicRouteTable ]
        [#if multiAZ!false ]
            [#local resourceZones = zones ]
        [#else]
            [#local resourceZones = [ zones[0] ]]
        [/#if]


        [#list resourceZones as zone ]
            [#local eipId = formatResourceId(AWS_EIP_RESOURCE_TYPE, core.Id, zone.Id) ]
            [#local zoneResources = mergeObjects( zoneResources,
                    {
                        zone.Id : {
                            "eip" : {
                                "Id" : eipId,
                                "Name" : formatName(core.FullName, zone.Name),
                                "Type" : AWS_EIP_RESOURCE_TYPE
                            }
                        }
                    } )]
        [/#list]
    [/#if]

    [#assign componentState =
        {
            "Resources" : {
                "transferserver" : {
                    "Id" : fileServerId,
                    "Name" : core.FullName,
                    "Type" : AWS_TRANSFER_SERVER_RESOURCE_TYPE
                },
                "logRole" : {
                    "Id" : formatResourceId(AWS_IAM_ROLE_RESOURCE_TYPE, core.Id),
                    "Type" : AWS_IAM_ROLE_RESOURCE_TYPE,
                    "IncludeInDeploymentState" : false
                },
                "lg" : {
                    "Id" : formatLogGroupId(core.Id),
                    "Type" : AWS_CLOUDWATCH_LOG_GROUP_RESOURCE_TYPE,
                    "IncludeInDeploymentState" : false
                },
                "sg" : {
                    "Id" : securityGroupId,
                    "Name" : core.FullName,
                    "Ports": availablePorts,
                    "Type" : AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE
                },
                "Zones" : zoneResources
            },
            "Attributes" : {
                "FQDN" : fqdn
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
                        "Ports" : [ availablePorts ],
                        "SecurityGroups" : securityGroupId,
                        "Description" : core.FullName
                    }
                }
            }
        }
    ]
[/#macro]
