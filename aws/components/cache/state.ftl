[#ftl]
[#macro aws_cache_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution ]

    [#local id = formatResourceId(AWS_CACHE_RESOURCE_TYPE, core.Id) ]
    [#local securityGroupId = formatDependentSecurityGroupId(id)]

    [#local engine = solution.Engine ]

    [#switch engine]
        [#case "memcached"]
            [#local engineVersion =
                valueIfContent(
                    solution.EngineVersion!"",
                    solution.EngineVersion!"",
                    "1.4.24"
                )
            ]
            [#local familyVersionIndex = engineVersion?last_index_of(".") - 1]
            [#local family = "memcached" + engineVersion[0..familyVersionIndex]]
            [#local port = solution.Port!"memcached" ]
            [#break]

        [#case "redis"]
            [#local engineVersion =
                valueIfContent(
                    solution.EngineVersion!"",
                    solution.EngineVersion!"",
                    "2.8.24"
                )
            ]
            [#local familyVersionIndex = engineVersion?last_index_of(".") - 1]
            [#local family = "redis" + engineVersion[0..familyVersionIndex]]
            [#local port = solution.Port!"redis" ]
            [#break]

        [#default]
            [@precondition
                function="setup_cache"
                context=occurrence
                detail="Unsupported engine provided"
            /]
            [#local engineVersion = "unknown" ]
            [#local family = "unknown" ]
            [#local port = "unknown" ]
    [/#switch]

    [#assign componentState =
        {
            "Resources" : {
                "cache" : {
                    "Id" : id,
                    "Name" : core.FullName,
                    "Type" : AWS_CACHE_RESOURCE_TYPE,
                    "Port" : port,
                    "Family" : family,
                    "EngineVersion" : engineVersion,
                    "Monitored" : true
                },
                "subnetGroup" : {
                    "Id" : formatResourceId(AWS_CACHE_SUBNET_GROUP_RESOURCE_TYPE, core.Id),
                    "Type" : AWS_CACHE_SUBNET_GROUP_RESOURCE_TYPE
                },
                "parameterGroup" : {
                    "Id" : formatResourceId(AWS_CACHE_PARAMETER_GROUP_RESOURCE_TYPE, core.Id),
                    "Type" : AWS_CACHE_PARAMETER_GROUP_RESOURCE_TYPE
                },
                "sg" : {
                    "Id" : securityGroupId,
                    "Name" : core.FullName,
                    "Type" : AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE
                }
            },
            "Attributes" : {
                "ENGINE" : engine,
                "FQDN"  : getExistingReference(AWS_PROVIDER, id, DNS_ATTRIBUTE_TYPE),
                "PORT" : getExistingReference(AWS_PROVIDER, id, PORT_ATTRIBUTE_TYPE),
                "URL" :
                    valueIfTrue(
                        "redis://",
                        engine == "redis",
                        "memcached://"
                    ) +
                    getExistingReference(AWS_PROVIDER, id, DNS_ATTRIBUTE_TYPE) +
                    ":" +
                    getExistingReference(AWS_PROVIDER, id, PORT_ATTRIBUTE_TYPE)
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
                        "Ports" : [ port ],
                        "SecurityGroups" : securityGroupId,
                        "Description" : core.FullName
                    }
                }
            }
        }
    ]
[/#macro]
