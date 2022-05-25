[#ftl]
[#macro aws_computecluster_cf_deployment_generationcontract_application occurrence ]
    [@addDefaultGenerationContract subsets=[ "pregeneration", "template" ] /]
[/#macro]

[#macro aws_computecluster_cf_deployment_application occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]
    [#local links = solution.Links ]

    [#local computeClusterRoleId               = resources["role"].Id ]
    [#local computeClusterInstanceProfileId    = resources["instanceProfile"].Id ]
    [#local computeClusterAutoScaleGroupId     = resources["autoScaleGroup"].Id ]
    [#local computeClusterAutoScaleGroupName   = resources["autoScaleGroup"].Name ]
    [#local computeClusterLaunchConfigId       = resources["launchConfig"].Id ]
    [#local computeClusterSecurityGroupId      = resources["securityGroup"].Id ]
    [#local computeClusterSecurityGroupName    = resources["securityGroup"].Name ]
    [#local computeClusterLogGroupId           = resources["lg"].Id]
    [#local computeClusterLogGroupName         = resources["lg"].Name]
    [#local computeClusterOS                   = (solution.ComputeInstance.OperatingSystem.Family)!"linux"]

    [#local processorProfile = getProcessor(occurrence, COMPUTECLUSTER_COMPONENT_TYPE)]
    [#local storageProfile   = getStorage(occurrence, COMPUTECLUSTER_COMPONENT_TYPE)]
    [#local logFileProfile   = getLogFileProfile(occurrence, COMPUTECLUSTER_COMPONENT_TYPE)]
    [#local bootstrapProfile = getBootstrapProfile(occurrence, COMPUTECLUSTER_COMPONENT_TYPE)]
    [#local networkProfile   = getNetworkProfile(occurrence)]
    [#local loggingProfile   = getLoggingProfile(occurrence)]

    [#local osPatching = mergeObjects(environmentObject.OSPatching, solution.ComputeInstance.OSPatching )]

    [#local autoScalingConfig = solution.AutoScaling ]

    [#local multiAZ = solution.MultiAZ]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "OpsData", "AppData", "Encryption", "SSHKey" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local operationsBucket = getExistingReference(baselineComponentIds["OpsData"]) ]
    [#local dataBucket = getExistingReference(baselineComponentIds["AppData"])]
    [#local kmsKeyId = baselineComponentIds["Encryption"]]

    [#local occurrenceNetwork = getOccurrenceNetwork(occurrence) ]
    [#local networkLink = occurrenceNetwork.Link!{} ]

    [#local networkLinkTarget = getLinkTarget(occurrence, networkLink ) ]

    [#if ! networkLinkTarget?has_content ]
        [@fatal message="Network could not be found" context=networkLink /]
        [#return]
    [/#if]

    [#local networkConfiguration = networkLinkTarget.Configuration.Solution]
    [#local networkResources = networkLinkTarget.State.Resources ]

    [#local vpcId = networkResources["vpc"].Id ]

    [#local routeTableLinkTarget = getLinkTarget(occurrence, networkLink + { "RouteTable" : occurrenceNetwork.RouteTable })]
    [#local routeTableConfiguration = routeTableLinkTarget.Configuration.Solution ]
    [#local publicRouteTable = routeTableConfiguration.Public ]

    [#local imageSource = solution.Image.Source]

    [#local buildUnit = getOccurrenceBuildUnit(occurrence)]
    [#if imageSource == "url" ]
        [#local buildUnit = occurrence.Core.Name ]
    [/#if]

    [#if deploymentSubsetRequired("pregeneration", false)]
        [#if imageSource = "url" ]
            [@addToDefaultBashScriptOutput
                content=
                    getImageFromUrlScript(
                        getRegion(),
                        productName,
                        environmentName,
                        segmentName,
                        occurrence,
                        solution.Image["Source:url"].Url,
                        "scripts",
                        "scripts.zip",
                        solution.Image["Source:url"].ImageHash,
                        true
                    )
            /]
        [/#if]
    [/#if]

    [#local targetGroupPermission = false ]
    [#local targetGroups = [] ]
    [#local loadBalancers = [] ]
    [#local environmentVariables = {}]

    [#local configSetName = occurrence.Core.Type]

    [#local ingressRules = []]

    [#list solution.Ports?values as port ]
        [#if port.LB.Configured]
            [#local lbLink = getLBLink(occurrence, port)]
            [#if isDuplicateLink(links, lbLink) ]
                [@fatal
                    message="Duplicate Link Name"
                    context=links
                    detail=lbLink /]
                [#continue]
            [/#if]
            [#local links += lbLink]
        [/#if]

        [#if port.IPAddressGroups?has_content ]
            [#local ingressRules +=
                [{
                    "Ports" : port.Name,
                    "IPAddressGroups" : port.IPAddressGroups
                }]]
        [/#if]
    [/#list]

    [#local scriptsFile = ""]
    [#if imageSource != "none" ]
        [#local scriptsPath =
                formatRelativePath(
                    getRegistryEndPoint("scripts", occurrence),
                    getRegistryPrefix("scripts", occurrence),
                    getOccurrenceBuildProduct(occurrence, productName),
                    getOccurrenceBuildScopeExtension(occurrence),
                    buildUnit,
                    getOccurrenceBuildReference(occurrence)
                )]

        [#local scriptsFile =
            formatRelativePath(
                scriptsPath,
                "scripts.zip"
            )
        ]
    [/#if]

    [#local contextLinks = getLinkTargets(occurrence, links) ]
    [#local _context =
        {
            "DefaultEnvironment" : defaultEnvironment(occurrence, contextLinks, baselineLinks),
            "Environment" : {},
            "Links" : contextLinks,
            "BaselineLinks" : baselineLinks,
            "DefaultCoreVariables" : true,
            "DefaultEnvironmentVariables" : true,
            "DefaultLinkVariables" : true,
            "DefaultBaselineVariables" : true,
            "Policy" : iamStandardPolicies(occurrence, baselineComponentIds),
            "ManagedPolicy" : [],
            "ComputeTasks" : [],
            "Files" : {},
            "Directories" : {},
            "StorageProfile" : storageProfile,
            "LogFileProfile" : logFileProfile,
            "BootstrapProfile" : bootstrapProfile,
            "InstanceLogGroup" : computeClusterLogGroupName,
            "InstanceOSPatching" : osPatching,
            "ScriptsFile" : scriptsFile
        }
    ]

    [#-- Add in extension specifics including override of defaults --]
    [#local _context = invokeExtensions( occurrence, _context )]
    [#local linkPolicies = getLinkTargetsOutboundRoles(_context.Links) ]

    [#-- Add policies for external log group access --]
    [#list ((logFileProfile.LogFileGroups)![])?map(
                x -> (getReferenceData(LOGFILEGROUP_REFERENCE_TYPE)[x])!{}
            )?filter(
                x -> x?has_content && x.LogStore.Destination == "link" ) as logFileGroup ]

        [#local linkPolicies = combineEntities(
            linkPolicies,
            getLinkTargetsOutboundRoles(
                getLinkTargets(
                    occurrence,
                    {
                        "logstore": mergeObjects(
                            {"Name" : "logstore", "Id": "logstore"},
                            logFileGroup.LogStore.Link
                        )
                    }
                )
            ),
            APPEND_COMBINE_BEHAVIOUR
        )]
    [/#list]

    [#local environmentVariables += getFinalEnvironment(occurrence, _context ).Environment ]

    [#local componentComputeTasks = resources["autoScaleGroup"].ComputeTasks]
    [#local userComputeTasks = solution.ComputeInstance.ComputeTasks.UserTasksRequired ]
    [#local computeTaskExtensions = solution.ComputeInstance.ComputeTasks.Extensions ]
    [#local computeTaskConfig = getOccurrenceComputeTaskConfig(occurrence, computeClusterAutoScaleGroupId, _context, computeTaskExtensions, componentComputeTasks, userComputeTasks)]

    [#list links?values as link]
        [#local linkTarget = getLinkTarget(occurrence, link) ]

        [@debug message="Link Target" context=linkTarget enabled=false /]

        [#if !linkTarget?has_content]
            [#continue]
        [/#if]

        [#local linkTargetCore = linkTarget.Core ]
        [#local linkTargetConfiguration = linkTarget.Configuration ]
        [#local linkTargetResources = linkTarget.State.Resources ]
        [#local linkTargetAttributes = linkTarget.State.Attributes ]

        [#local sourceSecurityGroupIds = []]
        [#local sourceIPAddressGroups = [] ]

        [#if deploymentSubsetRequired(COMPUTECLUSTER_COMPONENT_TYPE, true)]
            [@createSecurityGroupRulesFromLink
                occurrence=occurrence
                groupId=computeClusterSecurityGroupId
                linkTarget=linkTarget
                inboundPorts=solution.ComputeInstance.ManagementPorts
                networkProfile=networkProfile
            /]
        [/#if]

        [#switch linkTargetCore.Type]
            [#case LB_PORT_COMPONENT_TYPE]
            [#case LB_BACKEND_COMPONENT_TYPE]
                [#local targetGroupPermission = true]
                [#local destinationPort = linkTargetAttributes["DESTINATION_PORT"]]

                [#switch linkTargetAttributes["ENGINE"] ]
                    [#case "application" ]
                    [#case "classic"]
                        [#local sourceSecurityGroupIds += [ linkTargetResources["sg"].Id ] ]
                        [#break]
                    [#case "network" ]
                        [#local sourceIPAddressGroups = combineEntities(
                                                            sourceIPAddressGroups,
                                                            linkTargetConfiguration.Solution.IPAddressGroups + [ "_localnet" ],
                                                            UNIQUE_COMBINE_BEHAVIOUR
                                                        )]
                        [#break]
                [/#switch]

                [#switch linkTargetAttributes["ENGINE"]]

                    [#case "application"]
                    [#case "network"]
                        [#local targetGroups += [ linkTargetAttributes["TARGET_GROUP_ARN"] ] ]
                        [#break]

                    [#case "classic" ]
                        [#local lbId = linkTargetAttributes["LB"] ]
                        [#-- Classic ELB's register the instance so we only need 1 registration --]
                        [#local loadBalancers += [ getExistingReference(lbId) ]]
                        [#break]
                    [/#switch]
                [#break]

        [/#switch]

        [#if deploymentSubsetRequired(COMPUTECLUSTER_COMPONENT_TYPE, true)]

            [#local securityGroupCIDRs = getGroupCIDRs(sourceIPAddressGroups, true, occurrence)]
            [#list securityGroupCIDRs as cidr ]

                [@createSecurityGroupIngress
                    id=
                        formatDependentSecurityGroupIngressId(
                            computeClusterSecurityGroupId,
                            link.Id,
                            destinationPort,
                            replaceAlphaNumericOnly(cidr)
                        )
                    port=destinationPort
                    cidr=cidr
                    groupId=computeClusterSecurityGroupId
                /]
            [/#list]

            [#list sourceSecurityGroupIds as group ]
                [@createSecurityGroupIngress
                    id=
                        formatDependentSecurityGroupIngressId(
                            computeClusterSecurityGroupId,
                            link.Id,
                            destinationPort
                        )
                    port=destinationPort
                    group=group
                    groupId=computeClusterSecurityGroupId
                /]
            [/#list]
        [/#if]
    [/#list]

    [@setupLogGroup
        occurrence=occurrence
        logGroupId=computeClusterLogGroupId
        logGroupName=computeClusterLogGroupName
        loggingProfile=loggingProfile
        kmsKeyId=kmsKeyId
    /]

    [#if deploymentSubsetRequired("iam", true) &&
            isPartOfCurrentDeploymentUnit(computeClusterRoleId)]

        [@createRole
            id=computeClusterRoleId
            trustedServices=["ec2.amazonaws.com" ]
            policies=
                [
                    getPolicyDocument(
                        ec2AutoScaleGroupLifecyclePermission(
                            computeClusterAutoScaleGroupName
                        ) +
                        ec2ReadTagsPermission() +
                        s3ReadPermission(
                            formatRelativePath(
                                getRegistryEndPoint("scripts", occurrence),
                                getRegistryPrefix("scripts", occurrence)
                            )
                        ) +
                        s3AccountEncryptionReadPermission(
                            getRegistryBucket(),
                            getRegistryPrefix("scripts", occurrence),
                            getRegistryBucketRegion()
                        ) +
                        s3ListPermission(getCodeBucket()) +
                        s3ReadPermission(getCodeBucket()) +
                        s3AccountEncryptionReadPermission(
                            getCodeBucket(),
                            "*",
                            getCodeBucketRegion()
                        ) +
                        s3ListPermission(operationsBucket) +
                        s3WritePermission(operationsBucket, "DOCKERLogs") +
                        s3WritePermission(operationsBucket, "Backups") +
                        cwMetricsProducePermission("CWAgent") +
                        cwLogsProducePermission(computeClusterLogGroupName),
                        "basic"
                    ),
                    getPolicyDocument(
                        ssmSessionManagerPermission(computeClusterOS),
                        "ssm"
                    )
                ] +
                targetGroupPermission?then(
                    [
                        getPolicyDocument(
                            lbRegisterTargetPermission(),
                            "loadbalancing")
                    ],
                    []
                ) +
                arrayIfContent(
                    [getPolicyDocument(_context.Policy, "extension")],
                    _context.Policy
                ) +
                arrayIfContent(
                    [getPolicyDocument(linkPolicies, "links")],
                    linkPolicies)
            managedArns=
                _context.ManagedPolicy
            tags=getOccurrenceTags(occurrence)
        /]

    [/#if]

    [#if deploymentSubsetRequired(COMPUTECLUSTER_COMPONENT_TYPE, true)]

        [#if solution.ScalingPolicies?has_content ]
            [#list solution.ScalingPolicies as name, scalingPolicy ]
                [#local scalingPolicyId = resources["scalingPolicy" + name].Id ]

                [#local scalingMetricTrigger = scalingPolicy.TrackingResource.MetricTrigger ]

                [#switch scalingPolicy.Type?lower_case ]
                    [#case "stepped"]
                    [#case "tracked"]

                        [#if isPresent(scalingPolicy.TrackingResource.Link) ]

                            [#local scalingPolicyLink = scalingPolicy.TrackingResource.Link ]
                            [#local scalingPolicyLinkTarget = getLinkTarget(subOccurrence, scalingPolicyLink, false) ]

                            [@debug message="Scaling Link Target" context=scalingPolicyLinkTarget enabled=false /]

                            [#if !scalingPolicyLinkTarget?has_content]
                                [#continue]
                            [/#if]

                            [#local scalingTargetCore = scalingPolicyLinkTarget.Core ]
                            [#local scalingTargetResources = scalingPolicyLinkTarget.State.Resources ]
                        [#else]
                            [#local scalingTargetCore = core]
                            [#local scalingTargetResources = resources ]
                        [/#if]

                        [#local monitoredResources = getCWMonitoredResources(core.Id, scalingTargetResources, scalingMetricTrigger.Resource)]

                        [#if monitoredResources?keys?size > 1 ]
                            [@fatal
                                message="A scaling policy can only track one metric"
                                context={ "trackingPolicy" : name, "monitoredResources" : monitoredResources }
                                detail="Please add an extra resource filter to the metric policy"
                            /]
                            [#continue]
                        [/#if]

                        [#if ! monitoredResources?has_content ]
                            [@fatal
                                message="Could not find monitoring resources"
                                context={ "scalingPolicy" : scalingPolicy }
                                detail="Please make sure you have a resource which can be monitored with CloudWatch"
                            /]
                            [#continue]
                        [/#if]

                        [#local monitoredResource = monitoredResources[ (monitoredResources?keys)[0]] ]

                        [#local metricDimensions = getCWResourceMetricDimensions(monitoredResource, scalingTargetResources )]
                        [#local metricName = getCWMetricName(scalingMetricTrigger.Metric, monitoredResource.Type, scalingTargetCore.ShortFullName)]
                        [#local metricNamespace = getCWResourceMetricNamespace(monitoredResource.Type)]

                        [#if scalingPolicy.Type?lower_case == "stepped" ]
                            [#if ! isPresent( scalingPolicy.Stepped )]
                                [@fatal
                                    message="Stepped Scaling policy not found"
                                    context=scalingPolicy
                                    enabled=true
                                /]
                                [#continue]
                            [/#if]

                            [@createAlarm
                                id=formatDependentAlarmId(scalingPolicyId, monitoredResource.Id )
                                severity="Scaling"
                                resourceName=scalingTargetCore.FullName
                                alertName=scalingMetricTrigger.Name
                                actions=getReference( scalingPolicyId )
                                reportOK=false
                                metric=metricName
                                namespace=metricNamespace
                                description=scalingMetricTrigger.Name
                                threshold=scalingMetricTrigger.Threshold
                                statistic=scalingMetricTrigger.Statistic
                                evaluationPeriods=scalingMetricTrigger.Periods
                                period=scalingMetricTrigger.Time
                                operator=scalingMetricTrigger.Operator
                                missingData=scalingMetricTrigger.MissingData
                                unit=scalingMetricTrigger.Unit
                                dimensions=metricDimensions
                            /]

                            [#local scalingAction = []]
                            [#list scalingPolicy.Stepped.Adjustments?values as adjustment ]
                                    [#local scalingAction +=
                                                    getAutoScalingStepAdjustment(
                                                            adjustment.AdjustmentValue,
                                                            adjustment.LowerBound,
                                                            adjustment.UpperBound
                                                )]
                            [/#list]

                        [/#if]

                        [#if scalingPolicy.Type?lower_case == "tracked" ]

                            [#if ! isPresent( scalingPolicy.Tracked )]
                                [@fatal
                                    message="Tracked Scaling policy not found"
                                    context=scalingPolicy
                                    enabled=true
                                /]
                                [#continue]
                            [/#if]

                            [#local metricSpecification = getAutoScalingCustomTrackMetric(
                                                            getCWResourceMetricDimensions(monitoredResource, scalingTargetResources ),
                                                            getCWMetricName(scalingMetricTrigger.Metric, monitoredResource.Type, scalingTargetCore.ShortFullName),
                                                            getCWResourceMetricNamespace(monitoredResource.Type),
                                                            scalingMetricTrigger.Statistic
                                                        )]

                            [#local scalingAction = getEc2AutoScalingTrackPolicy(
                                                        scalingPolicy.Tracked.ScaleInEnabled,
                                                        scalingPolicy.Tracked.TargetValue,
                                                        metricSpecification
                                                    )]
                        [/#if]

                        [@createEc2AutoScalingPolicy
                                id=scalingPolicyId
                                autoScaleGroupId=computeClusterAutoScaleGroupId
                                scalingAction=scalingAction
                                policyType=scalingPolicy.Type
                                metricAggregationType=scalingPolicy.Stepped.MetricAggregation
                                adjustmentType=scalingPolicy.Stepped.CapacityAdjustment
                                minAdjustment=scalingPolicy.Stepped.MinAdjustment
                        /]
                        [#break]

                    [#case "scheduled"]
                        [#if ! isPresent( scalingPolicy.Scheduled )]
                            [@fatal
                                message="Scheduled Scaling policy not found"
                                context=scalingPolicy
                                enabled=true
                            /]
                            [#continue]
                        [/#if]

                        [#local scheduleProcessor = getProcessor(
                                                        occurrence,
                                                        COMPUTECLUSTER_COMPONENT_TYPE,
                                                        scalingPolicy.Scheduled.ProcessorProfile)]
                        [#local scheduleProcessorCounts = getProcessorCounts(scheduleProcessor, multiAZ ) ]
                        [@createEc2AutoScalingSchedule
                            id=scalingPolicyId
                            autoScaleGroupId=computeClusterAutoScaleGroupId
                            schedule=scalingPolicy.Scheduled.Schedule
                            processorCount=scheduleProcessorCounts
                        /]
                        [#break]
                [/#switch]
            [/#list]
        [/#if]

        [@createSecurityGroup
            id=computeClusterSecurityGroupId
            name=computeClusterSecurityGroupName
            vpcId=vpcId
            tags=getOccurrenceTags(occurrence)
        /]

        [@createSecurityGroupRulesFromNetworkProfile
            occurrence=occurrence
            groupId=computeClusterSecurityGroupId
            networkProfile=networkProfile
            inboundPorts=solution.ComputeInstance.ManagementPorts
        /]

        [#list ingressRules as ingressRule ]
            [@createSecurityGroupIngressFromNetworkRule
                occurrence=occurrence
                groupId=computeClusterSecurityGroupId
                networkRule=ingressRule
            /]
        [/#list]

        [@cfResource
            id=computeClusterInstanceProfileId
            type="AWS::IAM::InstanceProfile"
            properties=
                {
                    "Path" : "/",
                    "Roles" : [getReference(computeClusterRoleId)]
                }
            outputs={}
        /]

        [@createEc2AutoScaleGroup
            id=computeClusterAutoScaleGroupId
            tier=core.Tier
            computeTaskConfig=computeTaskConfig
            launchConfigId=computeClusterLaunchConfigId
            processorProfile=processorProfile
            autoScalingConfig=autoScalingConfig
            multiAZ=multiAZ
            targetGroups=targetGroups
            loadBalancers=loadBalancers
            tags=getOccurrenceTags(occurrence)
            networkResources=networkResources
        /]

        [@createEC2LaunchConfig
            id=computeClusterLaunchConfigId
            processorProfile=processorProfile
            storageProfile=_context.StorageProfile
            securityGroupId=computeClusterSecurityGroupId
            instanceProfileId=computeClusterInstanceProfileId
            resourceId=computeClusterAutoScaleGroupId
            imageId=getEC2AMIImageId(solution.ComputeInstance.Image, computeClusterLaunchConfigId)
            publicIP=publicRouteTable
            computeTaskConfig=computeTaskConfig
            environmentId=environmentId
            keyPairId=baselineComponentIds["SSHKey"]
        /]
    [/#if]
[/#macro]
