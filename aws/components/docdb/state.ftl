[#ftl]

[#macro aws_docdb_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local engineVersion = solution.EngineVersion!"3.6"]

    [#local resources = {}]
    [#local attributes = {}]
    [#local roles = {}]
    [#local port = solution.Port!"mongodb" ]
    [#local family = "docdb"+engineVersion ]

    [#if (ports[port])?has_content]
        [#local portObject = ports[port] ]
    [#else]
        [@fatal
            message="Unknown Port for docdb component type"
            context={
                "Id": occurrence.Core.RawId,
                "Port": port
            }
        /]
    [/#if]

    [#local id = formatResourceId(AWS_DDS_CLUSTER_RESOURCE_TYPE, core.Id) ]
    [#local securityGroupId = formatResourceId(AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE, core.Id)]

    [#local fqdn = getExistingReference(id, DNS_ATTRIBUTE_TYPE)]
    [#local name = getExistingReference(id, DATABASENAME_ATTRIBUTE_TYPE)]
    [#local region = getExistingReference(id, REGION_ATTRIBUTE_TYPE)]

    [#local readfqdn = getExistingReference(id, "read" + DNS_ATTRIBUTE_TYPE )]
    [#local attributes = mergeObjects(
        attributes,
        {
            "READ_FQDN" : readfqdn!""
        }
    )]

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
                    "URL" : getExistingReference(id, URL_ATTRIBUTE_TYPE)?ensure_starts_with(encryptionScheme),
                    "ENCRYPTION_SCHEME" : encryptionScheme,
                    "READ_URL" : getExistingReference(id, "read" + URL_ATTRIBUTE_TYPE)?ensure_starts_with(encryptionScheme)
                }
            )]
            [#break]

        [#case "Settings"]
            [#-- don't flag an error if credentials missing but component is not enabled --]
            [#local masterUsername = getOccurrenceSettingValue(occurrence, solution["rootCredential:Settings"].UsernameAttribute, !solution.Enabled) ]
            [#local masterPassword = getOccurrenceSettingValue(occurrence, solution["rootCredential:Settings"].PasswordAttribute, !solution.Enabled) ]
            [#local url = "mongodb://" + masterUsername + ":" + masterPassword + "@" + fqdn + ":" + (portObject.Port)!"" + "/" + name]

            [#local attributes = mergeObjects(
                attributes,
                {
                    "USERNAME" : masterUsername,
                    "PASSWORD" : masterPassword,
                    "URL" : url,
                    "READ_URL" : "mongodb://" + masterUsername + ":" + masterPassword + "@" + readfqdn + ":" + (portObject.Port)!"" + "/" + name
                }
            )]
            [#break]

        [#case "SecretStore"]

            [#local secretLink = getLinkTarget(occurrence, solution["rootCredential:SecretStore"].Link, false)]
            [#local secretEngine = secretLink.Configuration.Solution.Engine ]

            [#if secretLink.Core.Type == SECRETSTORE_COMPONENT_TYPE ]

                [#local baselineLinks = getBaselineLinks(occurrence, [ "Encryption"], true, false )]

                [#if baselineLinks?has_content ]
                    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
                    [#local cmkKeyId = (baselineComponentIds["Encryption"]) ]
                [#else]
                    [#local cmkKeyId = ""]
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

    [#local resources = mergeObjects(
        resources,
        {
            "dbCluster" : {
                "Id" : id,
                "Name" : core.FullName,
                "Port" : port,
                "Type" : AWS_DDS_CLUSTER_RESOURCE_TYPE,
                "Monitored" : true
            },
            "dbClusterParamGroup" : {
                "Id" : formatResourceId(AWS_DDS_CLUSTER_PARAMETER_GROUP_RESOURCE_TYPE, core.Id, replaceAlphaNumericOnly(family, "X") ),
                "Family" : family,
                "Type" : AWS_DDS_CLUSTER_PARAMETER_GROUP_RESOURCE_TYPE
            }
        }
    )]

    [#-- Calcuate the number of fixed instances required --]
    [#if multiAZ || (
            solution.Cluster.ScalingPolicies?has_content &&
            solution.Cluster.ScalingPolicies?values?map(x-> x.Enabled)?seq_contains(true)) ]
        [#local resourceZones = getZones() ]
    [#else]
        [#local resourceZones = [getZones()[0]] ]
    [/#if]

    [#local processor = getProcessor(occurrence, core.Type, solution.ProcessorProfile)]
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
        [#if solution.Cluster.ScalingPolicies?has_content &&
                solution.Cluster.ScalingPolicies?values?map(x-> x.Enabled)?seq_contains(true) ]

        [#-- Autoscaling requires 2 fixed instances at all times so we force it to be set --]
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
            [#if scalingPolicy.Enabled ]
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
                            "Id" : formatId( AWS_DDS_RESOURCE_TYPE, core.Id, resourceZone.Id, instanceId),
                            "Name" : formatName( core.FullName, resourceZone.Name, instanceId ),
                            "ZoneId" : resourceZone.Id,
                            "Type" : AWS_DDS_RESOURCE_TYPE
                        }
                    }
                }
            )]
        [/#list]
    [/#list]

    [#assign componentState =
        {
            "Resources" : mergeObjects(
                resources,
                {
                    "subnetGroup" : {
                        "Id" : formatResourceId(AWS_DDS_SUBNET_GROUP_RESOURCE_TYPE, core.Id),
                        "Type" : AWS_DDS_SUBNET_GROUP_RESOURCE_TYPE
                    },
                    "parameterGroup" : {
                        "Id" : formatResourceId(AWS_DDS_PARAMETER_GROUP_RESOURCE_TYPE, core.Id, replaceAlphaNumericOnly(family, "X") ),
                        "Family" : family,
                        "Type" : AWS_DDS_PARAMETER_GROUP_RESOURCE_TYPE
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
                    "TYPE" : "cluster",
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
