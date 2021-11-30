[#ftl]

[#macro aws_db_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local engine = solution.Engine]
    [#local engineVersion = solution.EngineVersion]

    [#local auroraCluster = false ]

    [#local resources = {}]
    [#local attributes = {}]
    [#local roles = {}]

    [#switch engine]
        [#case "mysql"]
            [#local family = "mysql" + engineVersion]
            [#local scheme = "mysql" ]
            [#local port = solution.Port!"mysql" ]
            [#break]

        [#case "postgres" ]
            [#local family = "postgres" + engineVersion]
            [#local scheme = "postgres" ]
            [#local port = solution.Port!"postgresql" ]
            [#break]

        [#case "sqlserver-ee"]
        [#case "sqlserver-se"]
        [#case "sqlserver-ex"]
        [#case "sqlserver-web"]
            [#local family = engine + "-" + engineVersion?remove_ending("0")]
            [#local scheme = engine ]
            [#local port = solution.Port!"sqlsvr" ]
            [#break]

        [#case "aurora-postgresql" ]
            [#local family = "aurora-postgresql" + engineVersion]
            [#local scheme = "postgres" ]
            [#local auroraCluster = true ]
            [#local port = solution.Port!"postgresql"]
            [#break]

        [#default]
            [#local family = engine + engineVersion]
            [#local scheme = engine ]
            [#local port = (solution.Port)!"" ]
    [/#switch]

    [#if (ports[port])?has_content]
        [#local portObject = ports[port] ]
    [#else]
        [@fatal message="Unknown Port" context=port /]
    [/#if]

    [#if auroraCluster ]
        [#local id = formatResourceId(AWS_RDS_CLUSTER_RESOURCE_TYPE, core.Id) ]
    [#else]
        [#local id = formatResourceId(AWS_RDS_RESOURCE_TYPE, core.Id) ]
    [/#if]

    [#local securityGroupId = formatDependentComponentSecurityGroupId(core.Tier, core.Component, id)]

    [#local fqdn = getExistingReference(id, DNS_ATTRIBUTE_TYPE)]
    [#local name = getExistingReference(id, DATABASENAME_ATTRIBUTE_TYPE)]
    [#local region = getExistingReference(id, REGION_ATTRIBUTE_TYPE)]

    [#if auroraCluster ]
        [#local readfqdn = getExistingReference(id, "read" + DNS_ATTRIBUTE_TYPE )]

        [#local attributes = mergeObjects(
            attributes,
            {
                "READ_FQDN" : readfqdn!""
            }
        )]
    [/#if]

    [#local credentialSource = solution["rootCredential:Source"]]
    [#if isPresent(solution["rootCredential:Generated"]) && credentialSource != "Generated"]
        [#local credentialSource = "Generated"]
    [/#if]

    [#switch credentialSource]
        [#case "Generated"]

            [#local encryptionScheme = (solution["rootCredential:Generated"].EncryptionScheme)?has_content?then(
                                solution["rootCredential:Generated"].EncryptionScheme?ensure_ends_with(":"),
                                "" )]

            [#local attributes = mergeObjects(
                attributes,
                {
                    "USERNAME" : solution["rootCredential:Generated"].Username,
                    "PASSWORD" : getExistingReference(id, GENERATEDPASSWORD_ATTRIBUTE_TYPE)?ensure_starts_with(encryptionScheme),
                    "URL" : getExistingReference(id, URL_ATTRIBUTE_TYPE)?ensure_starts_with(encryptionScheme)
                }
            )]

            [#if auroraCluster ]
                [#local attributes = mergeObjects(
                    attributes,
                    {
                        "READ_URL" : getExistingReference(id, "read" + URL_ATTRIBUTE_TYPE)?ensure_starts_with(encryptionScheme)
                    }
                )]
            [/#if]
            [#break]

        [#case "Settings"]
            [#-- don't flag an error if credentials missing but component is not enabled --]
            [#local masterUsername = getOccurrenceSettingValue(occurrence, solution["rootCredential:Settings"].UsernameAttribute, !solution.Enabled) ]
            [#local masterPassword = getOccurrenceSettingValue(occurrence, solution["rootCredential:Settings"].PasswordAttribute, !solution.Enabled) ]
            [#local url = scheme + "://" + masterUsername + ":" + masterPassword + "@" + fqdn + ":" + (portObject.Port)!"" + "/" + name]

            [#local attributes = mergeObjects(
                attributes,
                {
                    "USERNAME" : masterUsername,
                    "PASSWORD" : masterPassword,
                    "URL" : url
                }
            )]

            [#if auroraCluster ]
                [#local attributes = mergeObjects(
                    attributes,
                    {
                        "READ_URL" : scheme + "://" + masterUsername + ":" + masterPassword + "@" + readfqdn + ":" + (portObject.Port)!"" + "/" + name
                    }
                )]
            [/#if]
            [#break]

        [#case "SecretStore"]

            [#local secretLink = getLinkTarget(occurrence, solution["rootCredential:SecretStore"].Link, false)]

            [#if secretLink.Core.Type == SECRETSTORE_COMPONENT_TYPE ]

                [#local baselineLinks = getBaselineLinks(occurrence, [ "Encryption"], true, false )]

                [#if baselineLinks?has_content ]
                    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
                    [#local cmkKeyId = (baselineComponentIds["Encryption"]) ]

                    [#local secretLink = getLinkTarget(occurrence, solution.RootCredentials.Link, false)]
                    [#local secretEngine = secretLink.Configuration.Solution.Engine ]
                [#else]
                    [#local cmkKeyId = ""]
                    [#local secretEngine = ""]
                [/#if]

                [#local resources = mergeObjects(
                    resources,
                    {
                        "rootCredentials" :
                            getComponentSecretResources(
                                occurrence,
                                "RootCredentials",
                                "RootCredentials",
                                cmkKeyId,
                                secretEngine,
                                "Root credentials for database"
                            )
                    })]

                [#local roles = mergeObjects(
                    roles,
                    {
                        "Outbound" : {
                            "default" : "root",
                            "root" : secretsManagerReadPermission(resources["rootCredentials"]["secret"].Id, cmkKeyId)
                        }
                    }
                )]

                [#local attributes = mergeObjects(
                    attributes,
                    {
                        "SECRET_ARN" : getExistingReference(resources["rootCredentials"]["secret"].Id, ARN_ATTRIBUTE_TYPE)
                    }
                )]
            [/#if]

            [#local attributes = mergeObjects(
                attributes,
                {
                    "USERNAME" : solution["rootCredential:SecretStore"].UsernameAttribute,
                    "PASSWORD" : solution["rootCredential:SecretStore"].PasswordAttribute
                }
            )]
            [#break]
    [/#switch]

    [#if auroraCluster ]
        [#local resources = mergeObjects(
            resources,
            {
                "dbCluster" : {
                    "Id" : id,
                    "Name" : core.FullName,
                    "Port" : port,
                    "Type" : AWS_RDS_CLUSTER_RESOURCE_TYPE,
                    "Monitored" : true
                },
                "dbClusterParamGroup" : {
                    "Id" : formatResourceId(AWS_RDS_CLUSTER_PARAMETER_GROUP_RESOURCE_TYPE, core.Id, replaceAlphaNumericOnly(family, "X") ),
                    "Family" : family,
                    "Type" : AWS_RDS_CLUSTER_PARAMETER_GROUP_RESOURCE_TYPE
                }
            }
        )]

        [#-- Calcuate the number of fixed instances required --]
        [#if multiAZ!false ]
            [#local resourceZones = getZones() ]
        [#else]
            [#local resourceZones = [getZones()[0]] ]
        [/#if]

        [#local processor = getProcessor(occurrence, DB_COMPONENT_TYPE, solution.ProcessorProfile)]
        [#if processor.DesiredPerZone?has_content ]
                [#local instancesPerZone = processor.DesiredPerZone ]
        [#else]
            [#local processorCounts = getProcessorCounts(processor, multiAZ ) ]
            [#if processorCounts.DesiredCount?has_content ]
                [#local instancesPerZone = ( processorCounts.DesiredCount / resourceZones?size)?round ]
            [#else]
                [@fatal
                    message="Invalid Processor Profile for Cluster"
                    context=processor
                    detail="Add Autoscaling processing profile"
                /]
                [#return]
            [/#if]
        [/#if]

        [#local autoScaling = {}]
        [#if solution.Cluster.ScalingPolicies?has_content ]

            [#-- Autoscaling requires 2 fixed instances at all times so we force it to be set --]
            [#local resourceZones = getZones()[0..1]]
            [#local instancesPerZone = 1 ]

            [#local autoScaling +=
                {
                    "scalingTarget" : {
                        "Id" : formatResourceId(AWS_AUTOSCALING_APP_TARGET_RESOURCE_TYPE, core.Id),
                        "Type" : AWS_AUTOSCALING_APP_TARGET_RESOURCE_TYPE
                    }
                }
            ]
            [#list solution.Cluster.ScalingPolicies as name, scalingPolicy ]
                [#local autoScaling +=
                    {
                        "scalingPolicy" + name : {
                            "Id" : formatDependentAutoScalingAppPolicyId(id, name),
                            "Name" : formatName(core.FullName, name),
                            "Type" : AWS_AUTOSCALING_APP_POLICY_RESOURCE_TYPE
                        }
                    }
                ]
            [/#list]
        [/#if]
        [#local resources = mergeObjects( resources, autoScaling )]

        [#-- Define fixed instanaces per zone --]
        [#list resourceZones as resourceZone ]
            [#list 1..instancesPerZone as instanceId ]
                [#local resources = mergeObjects(
                    resources,
                    {
                        "dbInstances" : {
                            "dbInstance" + resourceZone.Id + instanceId : {
                                "Id" : formatId( AWS_RDS_RESOURCE_TYPE, core.Id, resourceZone.Id, instanceId),
                                "Name" : formatName( core.FullName, resourceZone.Name, instanceId ),
                                "ZoneId" : resourceZone.Id,
                                "Type" : AWS_RDS_RESOURCE_TYPE
                            }
                        }
                    }
                )]
            [/#list]
        [/#list]
    [#else]
        [#local resources = mergeObjects(
            resources,
            {
                "db" : {
                    "Id" : id,
                    "Name" : core.FullName,
                    "Port" : port,
                    "Type" : AWS_RDS_RESOURCE_TYPE,
                    "Monitored" : true
                }
            }
        )]
    [/#if]

    [#if  solution.Monitoring.DetailedMetrics.Enabled ]
        [#local resources = mergeObjects(
                resources,
                {
                    "monitoringRole" : {
                        "Id" : formatResourceId(AWS_IAM_ROLE_RESOURCE_TYPE, core.Id, "monitoring" ),
                        "Type" : AWS_IAM_ROLE_RESOURCE_TYPE,
                        "IncludeInDeploymentState" : false
                    }
                }
        )]
    [/#if]

    [#assign componentState =
        {
            "Resources" : mergeObjects(
                resources,
                {
                    "subnetGroup" : {
                        "Id" : formatResourceId(AWS_RDS_SUBNET_GROUP_RESOURCE_TYPE, core.Id),
                        "Type" : AWS_RDS_SUBNET_GROUP_RESOURCE_TYPE
                    },
                    "parameterGroup" : {
                        "Id" : formatResourceId(AWS_RDS_PARAMETER_GROUP_RESOURCE_TYPE, core.Id, replaceAlphaNumericOnly(family, "X") ),
                        "Family" : family,
                        "Type" : AWS_RDS_PARAMETER_GROUP_RESOURCE_TYPE
                    },
                    "optionGroup" : {
                        "Id" : formatResourceId(AWS_RDS_OPTION_GROUP_RESOURCE_TYPE, core.Id, replaceAlphaNumericOnly(family, "X")),
                        "Type" : AWS_RDS_OPTION_GROUP_RESOURCE_TYPE
                    },
                    "securityGroup" : {
                        "Id" : securityGroupId,
                        "Name" : core.FullName,
                        "Type" : AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE
                    }
                }
            ),
            "Attributes" : mergeObjects(
                attributes,
                {
                    "ENGINE" : engine,
                    "TYPE" : auroraCluster?then("cluster", "instance"),
                    "SCHEME" : scheme,
                    "FQDN" : fqdn,
                    "PORT" : (portObject.Port)!"",
                    "NAME" : name,
                    "INSTANCEID" : core.FullName,
                    "REGION" : region
                }
            ),
            "Roles" : mergeObjects(
                roles,
                {
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
            )
        }
    ]
[/#macro]
