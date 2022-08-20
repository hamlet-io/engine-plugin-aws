[#ftl]
[#macro aws_cache_cf_deployment_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract subsets="template" /]
[/#macro]

[#macro aws_cache_cf_deployment_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]

    [#local networkLink = getOccurrenceNetwork(occurrence).Link!{} ]

    [#local networkLinkTarget = getLinkTarget(occurrence, networkLink ) ]
    [#if ! networkLinkTarget?has_content ]
        [@fatal message="Network could not be found" context=networkLink /]
        [#return]
    [/#if]

    [#local networkConfiguration = networkLinkTarget.Configuration.Solution]
    [#local networkResources = networkLinkTarget.State.Resources ]

    [#local vpcId = networkResources["vpc"].Id ]

    [#local engine = solution.Engine]

    [#local cacheId = resources["cache"].Id ]
    [#local cacheFullName = resources["cache"].Name ]
    [#local cacheSubnetGroupId = resources["subnetGroup"].Id ]
    [#local cacheParameterGroupId = resources["parameterGroup"].Id ]
    [#local cacheSecurityGroupId = resources["sg"].Id ]
    [#local cacheSecurityGroupName = resources["sg"].Name ]

    [#local port = resources["cache"].Port ]
    [#local family = resources["cache"].Family ]
    [#local engineVersion = resources["cache"].EngineVersion ]

    [#local networkProfile = getNetworkProfile(occurrence)]
    [#local processorProfile = getProcessor(occurrence, CACHE_COMPONENT_TYPE)]

    [#local multiAZ = solution.MultiAZ]

    [#if (ports[port].Port)?has_content]
        [#local portObject = ports[port] ]
    [#else]
        [@fatal
            message="Unknown Port for cache component"
            context={
                "Id" : occurrence.Core.RawId,
                "Port" : port
            }
        /]
    [/#if]

    [#local countPerZone = processorProfile.CountPerZone]
    [#local awsZones = [] ]
    [#list getZones() as zone]
        [#list 1..countPerZone as i]
            [#local awsZones += [zone.AWSZone] ]
        [/#list]
    [/#list]

    [#local hibernate = solution.Hibernate.Enabled && isOccurrenceDeployed(occurrence)]

    [#list solution.Links?values as link]
        [#if link?is_hash]
            [#local linkTarget = getLinkTarget(occurrence, link) ]

            [@debug message="Link Target" context=linkTarget enabled=false /]

            [#if !linkTarget?has_content]
                [#continue]
            [/#if]

            [#local linkTargetCore = linkTarget.Core ]
            [#local linkTargetConfiguration = linkTarget.Configuration ]
            [#local linkTargetResources = linkTarget.State.Resources ]
            [#local linkTargetAttributes = linkTarget.State.Attributes ]

            [#if deploymentSubsetRequired("cache", true)]
                [@createSecurityGroupRulesFromLink
                    occurrence=occurrence
                    groupId=cacheSecurityGroupId
                    linkTarget=linkTarget
                    inboundPorts=[ port ]
                /]
            [/#if]

        [/#if]
    [/#list]

    [#if deploymentSubsetRequired("cache", true)]

        [@createSecurityGroup
            id=cacheSecurityGroupId
            name=cacheSecurityGroupName
            vpcId=vpcId
            tags=getOccurrenceTags(occurrence)
        /]

        [@createSecurityGroupRulesFromNetworkProfile
            occurrence=occurrence
            groupId=cacheSecurityGroupId
            networkProfile=networkProfile
            inboundPorts=[ port ]
        /]

        [#local ingressNetworkRule = {
                "Ports" : [ port ],
                "IPAddressGroups" : solution.IPAddressGroups
        }]

        [@createSecurityGroupIngressFromNetworkRule
            occurrence=occurrence
            groupId=cacheSecurityGroupId
            networkRule=ingressNetworkRule
        /]

        [@cfResource
            id=cacheSubnetGroupId
            type="AWS::ElastiCache::SubnetGroup"
            properties=
                {
                    "Description" : cacheFullName,
                    "SubnetIds" : getSubnets(core.Tier, networkResources)
                }
            outputs={}
        /]

        [@cfResource
            id=cacheParameterGroupId
            type="AWS::ElastiCache::ParameterGroup"
            properties=
                {
                    "CacheParameterGroupFamily" : family,
                    "Description" : cacheFullName,
                    "Properties" : {
                    }
                }
            outputs={}
        /]

        [#if !hibernate]

            [#if ! testMaintenanceWindow(solution.MaintenanceWindow)]
                [@fatal message="Maintenance window incorrectly configured" context=solution /]
                [#return]
            [/#if]

            [#list (solution.Alerts?values)?filter(x -> x.Enabled) as alert ]

                [#local monitoredResources = getCWMonitoredResources(core.Id, resources, alert.Resource)]
                [#list monitoredResources as name,monitoredResource ]

                    [@debug message="Monitored resource" context=monitoredResource enabled=false /]

                    [#switch alert.Comparison ]
                        [#case "Threshold" ]
                            [@createAlarm
                                id=formatDependentAlarmId(monitoredResource.Id, alert.Id )
                                severity=alert.Severity
                                resourceName=core.FullName
                                alertName=alert.Name
                                actions=getCWAlertActions(occurrence, solution.Profiles.Alert, alert.Severity )
                                metric=getCWMetricName(alert.Metric, monitoredResource.Type, core.ShortFullName)
                                namespace=getCWResourceMetricNamespace(monitoredResource.Type, alert.Namespace)
                                description=alert.Description!alert.Name
                                threshold=alert.Threshold
                                statistic=alert.Statistic
                                evaluationPeriods=alert.Periods
                                period=alert.Time
                                operator=alert.Operator
                                reportOK=alert.ReportOk
                                unit=alert.Unit
                                missingData=alert.MissingData
                                dimensions=getCWMetricDimensions(alert, monitoredResource, resources)
                            /]
                        [#break]
                    [/#switch]
                [/#list]
            [/#list]

            [@cfResource
                id=cacheId
                type="AWS::ElastiCache::CacheCluster"
                properties=
                    {
                        "Engine": engine,
                        "EngineVersion": engineVersion,
                        "CacheNodeType" : processorProfile.Processor,
                        "Port" : portObject.Port,
                        "CacheParameterGroupName": getReference(cacheParameterGroupId),
                        "CacheSubnetGroupName": getReference(cacheSubnetGroupId),
                        "VpcSecurityGroupIds":[getReference(cacheSecurityGroupId)]
                    } +
                    attributeIfContent(
                        "PreferredMaintenanceWindow",
                        solution.MaintenanceWindow.Configured?then(
                                getAmazonCacheMaintenanceWindow(
                                    solution.MaintenanceWindow.DayOfTheWeek,
                                    solution.MaintenanceWindow.TimeOfDay,
                                    solution.MaintenanceWindow.TimeZone
                                ),
                                ""
                            )

                    ) +
                    multiAZ?then(
                        {
                            "AZMode": "cross-az",
                            "PreferredAvailabilityZones" : getCFAWSAzReferences(getZones()?map( x -> x.Id)),
                            "NumCacheNodes" : processorProfile.CountPerZone * getZones()?size
                        },
                        {
                            "AZMode": "single-az",
                            "PreferredAvailabilityZone" : getCFAWSAzReference(getZones()[0].Id),
                            "NumCacheNodes" : processorProfile.CountPerZone
                        }
                    ) +
                    attributeIfContent("SnapshotRetentionLimit", solution.Backup.RetentionPeriod)
                tags=getOccurrenceTags(occurrence)
                outputs=engine?switch(
                    "memcached", MEMCACHED_OUTPUT_MAPPINGS,
                    "redis", REDIS_OUTPUT_MAPPINGS,
                    {})
            /]
        [/#if]
    [/#if]
[/#macro]
