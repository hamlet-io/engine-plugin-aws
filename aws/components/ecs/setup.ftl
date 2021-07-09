[#ftl]
[#macro aws_ecs_cf_deployment_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract subsets=[ "prologue", "template" ] /]
[/#macro]

[#macro aws_ecs_cf_deployment_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]
    [#local links = solution.Links ]

    [#local ecsId = resources["cluster"].Id ]
    [#local ecsName = resources["cluster"].Name ]
    [#local ecsRoleId = resources["role"].Id ]
    [#local ecsInstanceProfileId = resources["instanceProfile"].Id ]
    [#local ecsAutoScaleGroupId = resources["autoScaleGroup"].Id ]
    [#local ecsAutoScaleGroupName = resources["autoScaleGroup"].Name ]
    [#local ecsLaunchConfigId = resources["launchConfig"].Id ]
    [#local ecsSecurityGroupId = resources["securityGroup"].Id ]
    [#local ecsSecurityGroupName = resources["securityGroup"].Name ]
    [#local ecsLogGroupId = resources["lg"].Id ]
    [#local ecsLogGroupName = resources["lg"].Name ]
    [#local ecsInstanceLogGroupId = resources["lgInstanceLog"].Id]
    [#local ecsInstanceLogGroupName = resources["lgInstanceLog"].Name]
    [#local ecsEIPs = (resources["eips"])!{} ]

    [#local ecsCapacityProvierAssociationId = resources["ecsCapacityProviderAssociation"].Id ]
    [#local ecsASGCapacityProviderId = resources["ecsASGCapacityProvider"].Id]

    [#local cliAutoScaleGroupId = formatId(ecsAutoScaleGroupId, "cli" ) ]
    [#local cliECSClusterId = formatId(ecsId, "cli") ]

    [#local commandUpdateAutoScaleGroup = "updateAutoScaleGroup" ]

    [#local defaultLogDriver = solution.LogDriver ]
    [#local fixedIP = solution.FixedIP ]

    [#local cliRequired = false ]

    [#local managedTermination = false ]
    [#local autoScalingConfig = solution.AutoScaling ]

    [#local hibernate = solution.Hibernate.Enabled && isOccurrenceDeployed(occurrence)]

    [#local processorProfile        = getProcessor(occurrence, ECS_COMPONENT_TYPE)]
    [#local storageProfile          = getStorage(occurrence, ECS_COMPONENT_TYPE)]
    [#local logFileProfile          = getLogFileProfile(occurrence, ECS_COMPONENT_TYPE)]
    [#local bootstrapProfile        = getBootstrapProfile(occurrence, ECS_COMPONENT_TYPE)]
    [#local networkProfile          = getNetworkProfile(occurrence)]
    [#local loggingProfile          = getLoggingProfile(occurrence)]
    [#local computeProviderProfile  = getComputeProviderProfile(occurrence)]

    [#local osPatching = mergeObjects(solution.ComputeInstance.OSPatching, environmentObject.OSPatching )]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "OpsData", "AppData", "Encryption", "SSHKey" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]

    [#local operationsBucket = getExistingReference(baselineComponentIds["OpsData"]) ]
    [#local dataBucket = getExistingReference(baselineComponentIds["AppData"])]
    [#local sshKeyPairId = baselineComponentIds["SSHKey"]!"HamletFatal: sshKeyPairId not found" ]

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

    [#local ecsAsgTags = getOccurrenceCoreTags(occurrence, ecsAutoScaleGroupName, "", true)]
    [#local ecsTags = getOccurrenceCoreTags(occurrence, ecsName )]

    [#local environmentVariables = {}]

    [#local efsMountPoints = {}]

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
            "Policy" : standardPolicies(occurrence, baselineComponentIds),
            "ManagedPolicy" : [],
            "ComputeTasks" : [],
            "Files" : {},
            "Directories" : {},
            "StorageProfile" : storageProfile,
            "LogFileProfile" : logFileProfile,
            "BootstrapProfile" : bootstrapProfile,
            "InstanceLogGroup" : ecsInstanceLogGroupName,
            "InstanceOSPatching" : osPatching,
            "ElasticIPs" : ecsEIPs?values?map( eip -> eip.Id )
        }
    ]

    [#-- Add in extension specifics including override of defaults --]
    [#local _context = invokeExtensions( occurrence, _context )]

    [#local environmentVariables += getFinalEnvironment(occurrence, _context).Environment ]

    [#local configSetName = occurrence.Core.Type]

    [#local componentComputeTasks = resources["autoScaleGroup"].ComputeTasks]
    [#local userComputeTasks = solution.ComputeInstance.ComputeTasks.UserTasksRequired ]
    [#local computeTaskExtensions = solution.ComputeInstance.ComputeTasks.Extensions ]
    [#local computeTaskConfig = getOccurrenceComputeTaskConfig(occurrence, ecsAutoScaleGroupId, _context, computeTaskExtensions, componentComputeTasks, userComputeTasks)]

    [#if deploymentSubsetRequired("iam", true) &&
            isPartOfCurrentDeploymentUnit(ecsRoleId)]
        [#local linkPolicies = getLinkTargetsOutboundRoles(_context.Links) ]

        [@createRole
            id=ecsRoleId
            trustedServices=["ec2.amazonaws.com" ]
            managedArns=
                ["arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"] +
                _context.ManagedPolicy
            policies=
                [
                    getPolicyDocument(
                            ec2AutoScaleGroupLifecyclePermission(ecsAutoScaleGroupName) +
                            s3ListPermission(codeBucket) +
                            s3ReadPermission(credentialsBucket, accountId + "/alm/docker") +
                            s3AccountEncryptionReadPermission(
                                credentialsBucket,
                                "*",
                                credentialsBucketRegion
                            ) +
                            fixedIP?then(
                                ec2IPAddressUpdatePermission(),
                                []
                            ) +
                            s3ReadPermission(codeBucket) +
                            s3AccountEncryptionReadPermission(
                                codeBucket,
                                "*",
                                codeBucketRegion
                            ) +
                            s3ListPermission(operationsBucket) +
                            s3WritePermission(operationsBucket, getSegmentBackupsFilePrefix()) +
                            s3WritePermission(operationsBucket, "DOCKERLogs") +
                            cwLogsProducePermission(ecsLogGroupName) +
                            (solution.VolumeDrivers?seq_contains("ebs"))?then(
                                ec2EBSVolumeUpdatePermission(),
                                []
                            ),
                        "docker"
                    ),
                    getPolicyDocument(
                        ssmSessionManagerPermission(),
                        "ssm"
                    )
                ] +
                arrayIfContent(
                    [getPolicyDocument(_context.Policy, "extension")],
                    _context.Policy) +
                arrayIfContent(
                    [getPolicyDocument(linkPolicies, "links")],
                    linkPolicies)
        /]

    [/#if]

    [#if solution.ClusterLogGroup ]
        [@setupLogGroup
            occurrence=occurrence
            logGroupId=ecsLogGroupId
            logGroupName=ecsLogGroupName
            loggingProfile=loggingProfile
        /]
    [/#if]

    [@setupLogGroup
        occurrence=occurrence
        logGroupId=ecsInstanceLogGroupId
        logGroupName=ecsInstanceLogGroupName
        loggingProfile=loggingProfile
    /]

    [#local capacityProviderScalingPolicy = { "managedScaling" : false, "managedTermination" : false } ]

    [#if solution.HostScalingPolicies?has_content ]
        [#list solution.HostScalingPolicies as name, scalingPolicy ]

            [#switch scalingPolicy.Type?lower_case ]
                [#case "computeprovider"]
                    [#if ! capacityProviderScaling?has_content ]
                        [#local capacityProviderScalingPolicy += {
                                "managedScaling" : true,
                                "minStepSize" : scalingPolicy.ComputeProvider.MinAdjustment,
                                "maxStepSize" : scalingPolicy.ComputeProvider.MaxAdjustment,
                                "targetCapacity" : scalingPolicy.ComputeProvider.TargetCapacity,
                                "managedTermination" : scalingPolicy.ComputeProvider.ManageTermination
                        }]
                        [#local managedTermination = scalingPolicy.ComputeProvider.ManageTermination ]
                        [#if managedTermination
                                && !(autoScalingConfig.ReplaceCluster)
                                && !(autoScalingConfig.AlwaysReplaceOnUpdate)]
                            [@fatal
                                message="Incorrect AutoScaling configuration"
                                detail="Managed termination Compute provider scaling requires cluster replacement on update | Enable ReplaceCluster and AlwaysReplaceOnUpdate | Disable ManagedTermination in ComputeProider Scaling policy "
                                context={
                                    "AutoScaling" : autoScalingConfig
                                }
                                enabled=true
                            /]
                        [/#if]
                    [#else]
                        [@fatal
                            message="Only one compute provider scaling policy can be provided"
                            context=solution.HostScalingPolicies
                            enabled=true
                        /]
                    [/#if]
                    [#break]
                [#case "stepped"]
                [#case "tracked"]
                    [#local scalingPolicyId = resources["scalingPolicy" + name].Id ]
                    [#local scalingMetricTrigger = scalingPolicy.TrackingResource.MetricTrigger ]

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

                        [#if deploymentSubsetRequired("ecs", true)]
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
                        [/#if]

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

                    [#if deploymentSubsetRequired("ecs", true)]
                        [@createEc2AutoScalingPolicy
                                id=scalingPolicyId
                                autoScaleGroupId=ecsAutoScaleGroupId
                                scalingAction=scalingAction
                                policyType=scalingPolicy.Type
                                metricAggregationType=scalingPolicy.Stepped.MetricAggregation
                                adjustmentType=scalingPolicy.Stepped.CapacityAdjustment
                                minAdjustment=scalingPolicy.Stepped.MinAdjustment
                        /]
                    [/#if]
                    [#break]

                [#case "scheduled"]
                    [#local scalingPolicyId = resources["scalingPolicy" + name].Id ]
                    [#local scalingMetricTrigger = scalingPolicy.TrackingResource.MetricTrigger ]

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
                                                    ECS_COMPONENT_TYPE,
                                                    scalingPolicy.Scheduled.ProcessorProfile)]
                    [#local scheduleProcessorCounts = getProcessorCounts(scheduleProcessor, multiAZ ) ]
                    [#if deploymentSubsetRequired("ecs", true)]
                        [@createEc2AutoScalingSchedule
                            id=scalingPolicyId
                            autoScaleGroupId=ecsAutoScaleGroupId
                            schedule=scalingPolicy.Scheduled.Schedule
                            processorCount=scheduleProcessorCounts
                        /]
                    [/#if]
                    [#break]
            [/#switch]
        [/#list]
    [/#if]

    [#if deploymentSubsetRequired("ecs", true)]

        [#list _context.Links as linkId,linkTarget]
            [#local linkTargetCore = linkTarget.Core ]
            [#local linkTargetConfiguration = linkTarget.Configuration ]
            [#local linkTargetResources = linkTarget.State.Resources ]
            [#local linkTargetAttributes = linkTarget.State.Attributes ]
            [#local linkTargetRoles = linkTarget.State.Roles]

            [@createSecurityGroupRulesFromLink
                occurrence=occurrence
                groupId=ecsSecurityGroupId
                linkTarget=linkTarget
                inboundPorts=solution.ComputeInstance.ManagementPorts
                networkProfile=networkProfile
            /]

        [/#list]

        [@createSecurityGroup
            id=ecsSecurityGroupId
            name=ecsSecurityGroupName
            vpcId=vpcId
            occurrence=occurrence
        /]

        [@createSecurityGroupRulesFromNetworkProfile
            occurrence=occurrence
            groupId=ecsSecurityGroupId
            networkProfile=networkProfile
            inboundPorts=solution.ComputeInstance.ManagementPorts
        /]

        [#list resources.logMetrics!{} as logMetricName,logMetric ]

            [@createLogMetric
                id=logMetric.Id
                name=logMetric.Name
                logGroup=logMetric.LogGroupName
                filter=logFilters[logMetric.LogFilter].Pattern
                namespace=getCWResourceMetricNamespace(logMetric.Type)
                value=1
                dependencies=logMetric.LogGroupId
            /]

        [/#list]

        [#list solution.Alerts?values as alert ]

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
                            dimensions=getCWMetricDimensions(alert, monitoredResource, resources, environmentVariables)
                        /]
                    [#break]
                [/#switch]
            [/#list]
        [/#list]

        [#if processorProfile.MaxCount?has_content]
            [#local maxSize = processorProfile.MaxCount ]
        [#else]
            [#local maxSize = processorProfile.MaxPerZone]
            [#if multiAZ]
                [#local maxSize = maxSize * zones?size]
            [/#if]
        [/#if]

        [#local defaultCapacityProviderStrategies = [
            getECSCapacityProviderStrategy(computeProviderProfile.Containers.Default, ecsASGCapacityProviderId)
        ]]

        [#list (computeProviderProfile.Containers.Additional)?values as providerRule ]
            [#local defaultCapacityProviderStrategies +=
                [
                    getECSCapacityProviderStrategy(providerRule, ecsASGCapacityProviderId)
                ]
            ]
        [/#list]

        [@createECSCluster
            id=ecsId
            tags=ecsTags
        /]

        [#local capacityProviders =
            [
                "FARGATE",
                "FARGATE_SPOT",
                getReference(ecsASGCapacityProviderId)
            ]
        ]

        [@createECSCapacityProvider?with_args(capacityProviderScalingPolicy)
            id=ecsASGCapacityProviderId
            asgId=ecsAutoScaleGroupId
            tags=ecsTags
        /]

        [@createECSCapacityProviderAssociation
            id=ecsCapacityProvierAssociationId
            clusterId=ecsId
            capacityProviders=capacityProviders
            defaultCapacityProviderStrategies=defaultCapacityProviderStrategies
        /]

        [@cfResource
            id=ecsInstanceProfileId
            type="AWS::IAM::InstanceProfile"
            properties=
                {
                    "Path" : "/",
                    "Roles" : [getReference(ecsRoleId)]
                }
            outputs={}
        /]

        [#list ecsEIPs as index,eip ]
            [@createEIP
                id=eip["eip"].Id
                tags=getOccurrenceCoreTags(
                    occurrence,
                    eip["eip"].Name
                )
            /]
        [/#list]

        [@createEc2AutoScaleGroup
            id=ecsAutoScaleGroupId
            tier=core.Tier
            computeTaskConfig=computeTaskConfig
            launchConfigId=ecsLaunchConfigId
            processorProfile=processorProfile
            autoScalingConfig=autoScalingConfig
            multiAZ=multiAZ
            tags=ecsAsgTags
            networkResources=networkResources
            hibernate=hibernate
            scaleInProtection=managedTermination
        /]

        [@createEC2LaunchConfig
            id=ecsLaunchConfigId
            processorProfile=processorProfile
            storageProfile=_context.StorageProfile
            instanceProfileId=ecsInstanceProfileId
            securityGroupId=ecsSecurityGroupId
            resourceId=ecsAutoScaleGroupId
            imageId=getEC2AMIImageId(solution.ComputeInstance.Image, ecsLaunchConfigId)
            publicIP=publicRouteTable
            computeTaskConfig=computeTaskConfig
            environmentId=environmentId
            keyPairId=sshKeyPairId
        /]
    [/#if]

    [#-- prologue deprecation - ensures that old prologue scripts are removed --]
    [#if deploymentSubsetRequired("prologue", false)]
        [@addToDefaultBashScriptOutput
            content=[]
        /]
    [/#if]

    [#if managedTermination &&
            getExistingReference(ecsAutoScaleGroupId)?has_content &&
            deploymentSubsetRequired("prologue", false)]
        [@addToDefaultBashScriptOutput
            content=[
                r'remove_ec2_scaleinprotection "' + regionId + r'" "' + getExistingReference(ecsAutoScaleGroupId) + r'"'
            ]
        /]
    [/#if]

[/#macro]

[#macro aws_ecs_cf_deployment_generationcontract_application occurrence ]
    [@addDefaultGenerationContract subsets=[ "pregeneration", "prologue", "template", "epilogue", "cli"] /]
[/#macro]

[#macro aws_ecs_cf_deployment_application occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local parentResources = occurrence.State.Resources]
    [#local parentSolution = occurrence.Configuration.Solution ]

    [#local ecsId = parentResources["cluster"].Id ]
    [#local ecsClusterName = parentResources["cluster"].Name ]
    [#local ecsSecurityGroupId = parentResources["securityGroup"].Id ]
    [#local ecsASGCapacityProviderId = parentResources["ecsASGCapacityProvider"].Id]
    [#local essASGCapacityProviderAssociationId = parentResources["ecsCapacityProviderAssociation"].Id ]

    [#if ! (getExistingReference(ecsId)?has_content) ]
        [@fatal
            message="ECS Cluster not deployed or active"
            context={
                "ECSClusterId" : occurrence.Core.RawName,
                "DeployState" : isOccurrenceDeployed(occurrence)
            }
        /]
    [/#if]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "OpsData", "AppData", "Encryption" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local operationsBucket = getExistingReference(baselineComponentIds["OpsData"]) ]

    [#local occurrenceNetwork = getOccurrenceNetwork(occurrence) ]
    [#local networkLink = occurrenceNetwork.Link!{} ]

    [#local networkLinkTarget = getLinkTarget(occurrence, networkLink ) ]
    [#if ! networkLinkTarget?has_content ]
        [@fatal message="Network could not be found" context=networkLink /]
        [#return]
    [/#if]

    [#local networkConfiguration = networkLinkTarget.Configuration.Solution]
    [#local networkResources = networkLinkTarget.State.Resources ]

    [#local routeTableLinkTarget = getLinkTarget(occurrence, networkLink + { "RouteTable" : occurrenceNetwork.RouteTable })]
    [#local routeTableConfiguration = routeTableLinkTarget.Configuration.Solution ]
    [#local publicRouteTable = routeTableConfiguration.Public ]

    [#local vpcId = networkResources["vpc"].Id ]

    [#local hibernate = parentSolution.Hibernate.Enabled && isOccurrenceDeployed(occurrence) ]

    [#list requiredOccurrences(
            occurrence.Occurrences![],
            getCLODeploymentUnit(),
            getDeploymentGroup()) as subOccurrence]

        [@debug message="Suboccurrence" context=subOccurrence enabled=false /]

        [#local core = subOccurrence.Core ]
        [#local solution = subOccurrence.Configuration.Solution ]
        [#local resources = subOccurrence.State.Resources]

        [#local taskId = resources["task"].Id ]
        [#local taskName = resources["task"].Name ]
        [#local containers = getTaskContainers(occurrence, subOccurrence) ]

        [#local networkMode = solution.NetworkMode ]
        [#local lbTargetType = "instance"]
        [#local networkLinks = [] ]
        [#local executionRoleId = ""]

        [#local engine = solution.Engine?lower_case ]
        [#if engine == "aws:fargate" ]
            [#local engine = "fargate"]
        [/#if]

        [#local useCapacityProvider = true ]

        [#-- Provides warning for hosting updates this will still deploy but using fixed launch type --]
        [#-- Only use capacity providers when the assocation is in place --]
        [#if ( engine == "ec2") && ( ! (getExistingReference(essASGCapacityProviderAssociationId)?has_content)) ]
            [#local useCapacityProvider = false ]
            [@warn
                message="Could not find ECS Capacity provider for Ec2 - Update the solution ecs component"
                detail="Updating will use capacity providers which handle scaling up hosts for you"
                context={
                    "ECSId" : ecsClusterName,
                    "Service" : {
                        "Name" : core.RawName,
                        "Engine" : engine
                    }
                }
            /]
        [/#if]

        [#local subnets = multiAZ?then(
                getSubnets(core.Tier, networkResources),
                getSubnets(core.Tier, networkResources)[0..0]
            )]

        [#local networkProfile = getNetworkProfile(subOccurrence)]
        [#local loggingProfile = getLoggingProfile(subOccurrence)]

        [#if engine == "fargate" && networkMode != "awsvpc" ]
            [@fatal
                message="Fargate containers only support the awsvpc network mode"
                context=
                    {
                        "Description" : "Fargate containers only support the awsvpc network mode",
                        "NetworkMode" : networkMode
                    }
            /]
            [#break]
        [/#if]

        [#if networkMode == "awsvpc" ]

            [#local lbTargetType = "ip" ]

            [#local ecsSecurityGroupId = resources["securityGroup"].Id ]
            [#local ecsSecurityGroupName = resources["securityGroup"].Name ]

            [#local aswVpcNetworkConfiguration =
                {
                    "AwsvpcConfiguration" : {
                        "SecurityGroups" : getReferences(ecsSecurityGroupId),
                        "Subnets" : subnets,
                        "AssignPublicIp" : publicRouteTable?then("ENABLED", "DISABLED" )
                    }
                }
            ]

            [#if deploymentSubsetRequired("ecs", true)]
                [@createSecurityGroup
                    id=ecsSecurityGroupId
                    name=ecsSecurityGroupName
                    vpcId=vpcId
                    occurrence=subOccurrence
                /]

                [#local inboundPorts = []]
                [#list containers as container ]
                    [#local inboundPorts = combineEntities(
                                                inboundPorts,
                                                (container.InboundPorts)![],
                                                UNIQUE_COMBINE_BEHAVIOUR
                                            )]
                    [#list container.Links as id,link ]
                        [@createSecurityGroupRulesFromLink
                            occurrence=subOccurrence
                            groupId=ecsSecurityGroupId
                            inboundPorts=inboundPorts
                            linkTarget=link
                            networkProfile=networkProfile
                        /]
                    [/#list]
                [/#list]

                [@createSecurityGroupRulesFromNetworkProfile
                    occurrence=subOccurrence
                    groupId=ecsSecurityGroupId
                    networkProfile=networkProfile
                    inboundPorts=inboundPorts
                /]
            [/#if]
        [/#if]

        [#if core.Type == ECS_SERVICE_COMPONENT_TYPE]

            [#local serviceId = resources["service"].Id  ]
            [#local serviceDependencies = []]

            [#if deploymentSubsetRequired("ecs", true)]

                [#local useCircuitBreaker = true ]
                [#local loadBalancers = [] ]
                [#local serviceRegistries = []]
                [#local dependencies = [] ]
                [#list containers as container]

                    [#-- allow local network comms between containers in the same service --]
                    [#if solution.ContainerNetworkLinks ]
                        [#if networkMode == "bridge" || engine != "fargate" ]
                            [#local networkLinks += [ container.Name ] ]
                        [#else]
                            [@fatal
                                message="Network links only avaialble on bridge mode and ec2 engine"
                                context=
                                    {
                                        "Description" : "Container links are only available in bridge mode and ec2 engine",
                                        "NetworkMode" : networkMode
                                    }
                            /]
                        [/#if]
                    [/#if]

                    [#list container.PortMappings![] as portMapping]
                        [#if portMapping.LoadBalancer?has_content]
                            [#local loadBalancer = portMapping.LoadBalancer]
                            [#local link = container.Links[loadBalancer.Link] ]
                            [@debug message="Link" context=link enabled=false /]
                            [#local linkCore = link.Core ]
                            [#local linkResources = link.State.Resources ]
                            [#local linkConfiguration = link.Configuration.Solution ]
                            [#local linkAttributes = link.State.Attributes ]
                            [#local targetId = "" ]

                            [#local sourceSecurityGroupIds = []]
                            [#local sourceIPAddressGroups = [] ]

                            [#switch linkCore.Type]

                                [#case LB_PORT_COMPONENT_TYPE]

                                    [#switch linkAttributes["ENGINE"] ]
                                        [#case "application" ]
                                        [#case "classic"]
                                            [#local sourceSecurityGroupIds += [ linkResources["sg"].Id ] ]
                                            [#break]
                                        [#case "network" ]
                                            [#local sourceIPAddressGroups = linkConfiguration.IPAddressGroups + [ "_localnet" ] ]
                                            [#break]
                                    [/#switch]

                                    [#switch linkAttributes["ENGINE"] ]
                                        [#case "network" ]
                                        [#case "application" ]
                                            [#local loadBalancers +=
                                                [
                                                    {
                                                        "ContainerName" : container.Name,
                                                        "ContainerPort" : ports[portMapping.ContainerPort].Port,
                                                        "TargetGroupArn" : linkAttributes["TARGET_GROUP_ARN"]
                                                    }
                                                ]
                                            ]
                                            [#break]

                                        [#case "classic"]
                                            [#if networkMode == "awsvpc" ]
                                                [@fatal
                                                    message="Network mode not compatible with LB"
                                                    context=
                                                        {
                                                            "Description" : "The current container network mode is not compatible with this load balancer engine",
                                                            "NetworkMode" : networkMode,
                                                            "LBEngine" : linkAttributes["ENGINE"]
                                                        }
                                                /]
                                            [/#if]

                                            [#-- ECS Service Circuit breaker not supported with classic lb --]
                                            [#local useCircuitBreaker = false ]

                                            [#local lbId =  linkAttributes["LB"] ]
                                            [#-- Classic ELB's register the instance so we only need 1 registration --]
                                            [#-- TODO: Change back to += when AWS allows multiple load balancer registrations per container --]
                                            [#local loadBalancers =
                                                [
                                                    {
                                                        "ContainerName" : container.Name,
                                                        "ContainerPort" : ports[portMapping.ContainerPort].Port,
                                                        "LoadBalancerName" : getExistingReference(lbId)
                                                    }
                                                ]
                                            ]

                                            [#break]
                                    [/#switch]
                                [#break]
                            [/#switch]

                            [#local dependencies += [targetId] ]

                            [#local securityGroupCIDRs = getGroupCIDRs(sourceIPAddressGroups, true, subOccurrence)]
                            [#list securityGroupCIDRs as cidr ]

                                [@createSecurityGroupIngress
                                    id=
                                        formatContainerSecurityGroupIngressId(
                                            ecsSecurityGroupId,
                                            container,
                                            portMapping.DynamicHostPort?then(
                                                "dynamic",
                                                ports[portMapping.HostPort].Port
                                            ),
                                            replaceAlphaNumericOnly(cidr)
                                        )
                                    port=portMapping.DynamicHostPort?then(0, portMapping.HostPort)
                                    cidr=cidr
                                    groupId=ecsSecurityGroupId
                            /]
                            [/#list]

                            [#list sourceSecurityGroupIds as group ]
                                [@createSecurityGroupIngress
                                    id=
                                        formatContainerSecurityGroupIngressId(
                                            ecsSecurityGroupId,
                                            container,
                                            portMapping.DynamicHostPort?then(
                                                "dynamic",
                                                ports[portMapping.HostPort].Port
                                            )
                                        )
                                    port=portMapping.DynamicHostPort?then(0, portMapping.HostPort)
                                    group=group
                                    groupId=ecsSecurityGroupId
                                /]
                            [/#list]
                        [/#if]

                        [#if portMapping.ServiceRegistry?has_content]
                            [#local serviceRegistry = portMapping.ServiceRegistry]

                            [#local link = (container.Links[serviceRegistry.Link])!{} ]
                            [#if ! link?has_content ]
                                [@fatal message="could not find registry link" context=serviceRegistry enabled=true /]
                                [#continue]
                            [/#if]

                            [@debug message="Link" context=link enabled=false /]
                            [#local linkCore = link.Core ]
                            [#local linkResources = link.State.Resources ]
                            [#local linkConfiguration = link.Configuration.Solution ]
                            [#local linkAttributes = link.State.Attributes ]

                            [#switch linkCore.Type]

                                [#case SERVICE_REGISTRY_SERVICE_COMPONENT_TYPE]

                                    [#local serviceRecordTypes = linkAttributes["RECORD_TYPES"]?split(",") ]

                                    [#local portAttributes = {}]
                                    [#if serviceRecordTypes?seq_contains("SRV") ]
                                        [#local portAttributes = {
                                            "ContainerPort" : ports[portMapping.ContainerPort].Port
                                        }]
                                    [/#if]

                                    [#if serviceRecordTypes?seq_contains("A") && networkMode != "awsvpc" ]
                                        [@fatal message="A record registration only availalbe on awsvpc network Type" context=link /]
                                    [/#if]

                                    [#if serviceRecordTypes?seq_contains("AAAA") ]
                                        [@fatal message="AAAA Service record are not supported" context=link /]
                                    [/#if]

                                    [#local serviceRegistries +=
                                        [
                                            {
                                                "ContainerName" : container.Name,
                                                "RegistryArn" : linkAttributes["SERVICE_ARN"]
                                            } +
                                            portAttributes
                                        ]
                                    ]
                                    [#break]
                            [/#switch]
                        [/#if]
                    [/#list]
                    [#if container.IngressRules?has_content ]
                        [#list container.IngressRules as ingressRule ]
                            [@createSecurityGroupIngress
                                    id=formatContainerSecurityGroupIngressId(
                                            ecsSecurityGroupId,
                                            container,
                                            ingressRule.port,
                                            replaceAlphaNumericOnly(ingressRule.cidr)
                                        )
                                    port=ingressRule.port
                                    cidr=ingressRule.cidr
                                    groupId=ecsSecurityGroupId
                                /]
                        [/#list]
                    [/#if]

                    [#if container.LinkIngressRules?has_content ]
                        [#list container.LinkIngressRules as linkIngressRule ]
                            [@createSecurityGroupIngressFromNetworkRule
                                occurrence=subOccurrence
                                groupId=ecsSecurityGroupId
                                networkRule=linkIngressRule
                            /]
                        [/#list]
                    [/#if]

                    [#if !(networkProfile.BaseSecurityGroup.Outbound.GlobalAllow)
                            && container.EgressRules?has_content ]
                        [#list container.EgressRules as egressRule ]
                            [@createSecurityGroupEgressFromNetworkRule
                                occurrence=subOccurrence
                                groupId=ecsSecurityGroupId
                                networkRule=egressRule
                            /]
                        [/#list]
                    [/#if]
                [/#list]

                [#local processorProfile = getProcessor(subOccurrence, ECS_SERVICE_COMPONENT_TYPE)]
                [#local processorCounts = getProcessorCounts(processorProfile, multiAZ, solution.DesiredCount ) ]

                [#local desiredCount = processorCounts.DesiredCount ]
                [#if hibernate ]
                    [#local desiredCount = 0 ]
                [/#if]

                [#if solution.ScalingPolicies?has_content ]
                    [#local scalingTargetId = resources["scalingTarget"].Id ]

                    [#local serviceResourceType = resources["service"].Type ]]

                    [#local scheduledActions = []]
                    [#list solution.ScalingPolicies as name, scalingPolicy ]
                        [#local scalingPolicyId = resources["scalingPolicy" + name].Id ]
                        [#local scalingPolicyName = resources["scalingPolicy" + name].Name ]

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
                                    [#local scalingTargetResources = resources + { "cluster" : parentResources["cluster"] }]
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
                                        resourceName=concatenate( [ core.FullName, scalingTargetCore.FullName], "|" )
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

                                    [#local stepAdjustments = []]
                                    [#list scalingPolicy.Stepped.Adjustments?values as adjustment ]
                                            [#local stepAdjustments +=
                                                         getAutoScalingStepAdjustment(
                                                                    adjustment.AdjustmentValue,
                                                                    adjustment.LowerBound,
                                                                    adjustment.UpperBound
                                                        )]
                                    [/#list]

                                    [#local scalingAction = getAutoScalingAppStepPolicy(
                                                            scalingPolicy.Stepped.CapacityAdjustment,
                                                            scalingPolicy.Cooldown.ScaleIn,
                                                            scalingPolicy.Stepped.MetricAggregation,
                                                            scalingPolicy.Stepped.MinAdjustment,
                                                            stepAdjustments
                                    )]

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

                                    [#if (scalingPolicy.Tracked.RecommendedMetric)?has_content ]
                                        [#local specificationType = "predefined" ]
                                        [#local metricSpecification = getAutoScalingPredefinedTrackMetric(scalingPolicy.Tracked.RecommendedMetric)]
                                    [#else ]
                                        [#local specificationType = "custom" ]
                                        [#local metricSpecification = getAutoScalingCustomTrackMetric(
                                                                        getCWResourceMetricDimensions(monitoredResource, scalingTargetResources ),
                                                                        getCWMetricName(scalingMetricTrigger.Metric, monitoredResource.Type, scalingTargetCore.ShortFullName),
                                                                        getCWResourceMetricNamespace(monitoredResource.Type),
                                                                        scalingMetricTrigger.Statistic
                                                                    )]
                                    [/#if]

                                    [#local scalingAction = getAutoScalingAppTrackPolicy(
                                                                scalingPolicy.Tracked.ScaleInEnabled,
                                                                scalingPolicy.Cooldown.ScaleIn,
                                                                scalingPolicy.Cooldown.ScaleOut,
                                                                scalingPolicy.Tracked.TargetValue,
                                                                specificationType,
                                                                metricSpecification
                                                            )]
                                [/#if]

                                [@createAutoScalingAppPolicy
                                    id=scalingPolicyId
                                    name=scalingPolicyName
                                    policyType=scalingPolicy.Type
                                    scalingAction=scalingAction
                                    scalingTargetId=scalingTargetId
                                /]
                                [#break]

                            [#case "scheduled"]
                                [#if ! isPresent( scalingPolicy.Scheduled )]
                                    [@fatal
                                        message="Tracked Scaling policy not found"
                                        context=scalingPolicy
                                        enabled=true
                                    /]
                                    [#continue]
                                [/#if]

                                [#local scheduleProcessor = getProcessor(
                                                                subOccurrence,
                                                                ECS_SERVICE_COMPONENT_TYPE,
                                                                scalingPolicy.Scheduled.ProcessorProfile)]
                                [#local scheduleProcessorCounts = getProcessorCounts(scheduleProcessor, multiAZ ) ]
                                [#local scheduledActions += [
                                    {
                                        "ScalableTargetAction" : {
                                            "MaxCapacity" : scheduleProcessorCounts.MaxCount,
                                            "MinCapacity" : scheduleProcessorCounts.MinCount
                                        },
                                        "Schedule" : scalingPolicy.Scheduled.Schedule,
                                        "ScheduledActionName" : scalingPolicyName
                                    }
                                ]]
                                [#break]
                        [/#switch]
                    [/#list]


                    [@createAutoScalingAppTarget
                        id=scalingTargetId
                        minCount=processorCounts.MinCount
                        maxCount=processorCounts.MaxCount
                        scalingResourceId=getAutoScalingAppEcsResourceId(ecsId, serviceId)
                        scalableDimension="ecs:service:DesiredCount"
                        resourceType=serviceResourceType
                        scheduledActions=scheduledActions
                    /]

                [/#if]

                [#local capacityProviderStrategy = []]

                [#local baseCapacityProvider = solution.Placement.ComputeProvider.Default ]
                [#local additionalCapacityProviders = solution.Placement.ComputeProvider.Additional ]

                [#if useCapacityProvider ]
                    [#switch engine ]
                        [#case "ec2"]
                            [#if baseCapacityProvider.Provider == "_engine" ]
                                [#local capacityProviderStrategy += [
                                    getECSCapacityProviderStrategy(
                                        baseCapacityProvider + { "Provider" : "_autoscalegroup" },
                                        ecsASGCapacityProviderId
                                    )
                                ]]
                            [#else]
                                [@fatal
                                    message="ECS Service engine Ec2 only supports the _engine compute provider"
                                    context={
                                        "ServiceId" : core.RawId,
                                        "Engine" : engine,
                                        "DefaultComputeProvider" : baseCapacityProvider
                                    }
                                /]
                            [/#if]

                            [#if additionalCapacityProviders?has_content ]
                                [@fatal
                                    message="ECS Service engine Ec2 doesn't support additional compute providers"
                                    context={
                                        "ServiceId" : core.RawId,
                                        "Engine" : engine,
                                        "AdditonalComputeProvider" : additionalCapacityProviders
                                    }
                                /]
                            [/#if]
                            [#break]

                        [#case "aws:fargate"]
                        [#case "fargate"]
                            [#if baseCapacityProvider.Provider == "_engine" ]
                                [#local capacityProviderStrategy += [
                                    getECSCapacityProviderStrategy(
                                        baseCapacityProvider + { "Provider" : "aws:fargate" }
                                    )
                                ]]
                            [#elseif baseCapacityProvider.Provider == "aws:fargate" || baseCapacityProvider.Provider == "aws:fargate_spot" ]
                                [#local capacityProviderStrategy += [
                                    getECSCapacityProviderStrategy(
                                        baseCapacityProvider
                                    )
                                ]]
                            [#else]
                                [@fatal
                                    message="ECS Service engine fargate only supports fargate based providers"
                                    context={
                                        "ServiceId" : core.RawId,
                                        "Engine" : engine,
                                        "DefaultComputeProvider" : baseCapacityProvider
                                    }
                                /]
                            [/#if]

                            [#list additionalCapacityProviders?values as additionalProvider]
                                [#if additionalProvider.Provider == "_engine"]
                                    [#local additionalProvider += { "Provider" : "aws:fargate" }]
                                [/#if]

                                [#if [ "aws:fargate", "aws:fargate_spot" ]?seq_contains(additionalProvider.Provider) ]
                                    [#local capacityProviderStrategy += [
                                        getECSCapacityProviderStrategy(
                                            additionalProvider
                                        )
                                    ]]
                                [#else]
                                    [@fatal
                                        message="ECS Service engine fargate only supports fargate based providers"
                                        context={
                                            "ServiceId" : core.RawId,
                                            "Engine" : engine,
                                            "AdditonalComputeProviders" : additionalCapacityProviders
                                        }
                                    /]
                                [/#if]
                            [/#list]
                            [#break]
                    [/#switch]
                [/#if]

                [@createECSService
                    id=serviceId
                    ecsId=ecsId
                    engine=engine
                    desiredCount=desiredCount
                    taskId=taskId
                    loadBalancers=loadBalancers
                    serviceRegistries=serviceRegistries
                    networkMode=networkMode
                    networkConfiguration=aswVpcNetworkConfiguration!{}
                    placement=solution.Placement
                    platformVersion=solution["aws:FargatePlatform"]
                    capacityProviderStrategy=capacityProviderStrategy
                    dependencies=dependencies
                    circuitBreaker=useCircuitBreaker
                /]
            [/#if]
        [/#if]

        [#local dependencies = [] ]
        [#local roleId = "" ]
        [#if solution.UseTaskRole]
            [#local roleId = resources["taskrole"].Id ]
            [#if deploymentSubsetRequired("iam", true) && isPartOfCurrentDeploymentUnit(roleId)]
                [#local managedPolicy = []]

                [#list containers as container]
                    [#if container.ManagedPolicy?has_content ]
                        [#local managedPolicy += container.ManagedPolicy ]
                    [/#if]

                    [#if container.Policy?has_content]
                        [#local policyId = formatDependentPolicyId(taskId, container.Id) ]
                        [@createPolicy
                            id=policyId
                            name=container.Name
                            statements=container.Policy
                            roles=roleId
                        /]
                        [#local dependencies += [policyId] ]
                    [/#if]

                    [#local linkPolicies = getLinkTargetsOutboundRoles(container.Links) ]

                    [#if linkPolicies?has_content]
                        [#local policyId = formatDependentPolicyId(taskId, container.Id, "links")]
                        [@createPolicy
                            id=policyId
                            name="links"
                            statements=linkPolicies
                            roles=roleId
                        /]
                        [#local dependencies += [policyId] ]
                    [/#if]
                [/#list]

                [@createRole
                    id=roleId
                    trustedServices=["ecs-tasks.amazonaws.com"]
                    managedArns=managedPolicy
                /]
            [/#if]
        [/#if]

        [#local executionRoleId = ""]
        [#if resources["executionRole"]?has_content ]
            [#local executionRoleId = resources["executionRole"].Id]
            [#if deploymentSubsetRequired("iam", true ) && isPartOfCurrentDeploymentUnit(executionRoleId) ]
                [@createRole
                    id=executionRoleId
                    trustedServices=[
                        "ecs-tasks.amazonaws.com"
                    ]
                    managedArns=["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
                /]
            [/#if]
        [/#if]

        [#if core.Type == ECS_TASK_COMPONENT_TYPE]
            [#if solution.Schedules?has_content ]

                [#local ruleCleanupScript = []]
                [#local ruleCleanupOutput = {}]
                [#local cliCleanUpRequired = false]

                [#local scheduleTaskRoleId = resources["scheduleRole"].Id ]
                [#if deploymentSubsetRequired("iam", true) && isPartOfCurrentDeploymentUnit(scheduleTaskRoleId)]
                    [@createRole
                        id=scheduleTaskRoleId
                        trustedServices=["events.amazonaws.com"]
                        policies=[
                            getPolicyDocument(
                                ecsTaskRunPermission(ecsId) +
                                roleId?has_content?then(
                                    iamPassRolePermission(
                                        getReference(roleId, ARN_ATTRIBUTE_TYPE)
                                    ),
                                    []
                                ) +
                                executionRoleId?has_content?then(
                                    iamPassRolePermission(
                                        getReference(executionRoleId, ARN_ATTRIBUTE_TYPE)
                                    ),
                                    []
                                ),
                                "schedule"
                            )
                        ]
                    /]
                [/#if]

                [#list solution.Schedules?values as schedule ]

                    [#local scheduleRuleId = resources["schedules"][schedule.Id]["schedule"].Id ]
                    [#local cliCleanUpRequired = cliCleanUpRequired?then(
                                cliCleanUpRequired,
                                getExistingReference(scheduleRuleId, "cleanup")?has_content
                    )]

                    [#local scheduleEnabled = hibernate?then(
                                false,
                                schedule.Enabled
                    )]

                    [#local ecsParameters = {
                        "TaskCount" : schedule.TaskCount,
                        "TaskDefinitionArn" : getReference(taskId, ARN_ATTRIBUTE_TYPE),
                        "LaunchType" : "EC2"
                     }]

                    [#if networkMode == "awsvpc" ]
                        [#local ecsParameters += {
                            "NetworkConfiguration" : {
                                "AwsVpcConfiguration" : {
                                    "Subnets" : subnets,
                                    "AssignPublicIp" : publicRouteTable?then(
                                                        "ENABLE",
                                                        "DISABLED"
                                                    )
                                }
                            }
                        }]
                    [/#if]

                    [#if engine == "fargate" ]
                        [#local ecsParameters += {
                            "PlatformVersion" : solution["aws:FargatePlatform"],
                            "LaunchType" : "FARGATE"
                        }]
                    [/#if]

                    [#local targetParameters = {
                        "Arn" : getExistingReference(ecsId, ARN_ATTRIBUTE_TYPE),
                        "Id" : taskId,
                        "EcsParameters" : ecsParameters,
                        "RoleArn" : getReference(scheduleTaskRoleId, ARN_ATTRIBUTE_TYPE)
                    }]

                    [#if deploymentSubsetRequired("ecs", true) ]
                        [@createScheduleEventRule
                            id=scheduleRuleId
                            enabled=scheduleEnabled
                            scheduleExpression=schedule.Expression
                            targetParameters=targetParameters
                        /]
                    [/#if]

                    [#local ruleCleanupScript += [
                        "       delete_cloudwatch_event" +
                        "       \"" + region + "\" " +
                        "       \"" + scheduleRuleId + "\" " +
                        "       \"true\" || return $?"
                        ]]

                    [#local ruleCleanupOutput += {
                            formatId(scheduleRuleId, "cleanup") : true?c
                        }]
                [/#list]

                [#-- running epilogue script when we first time update stack with switching --]
                [#-- from to the cli-created to CF schedule CW rules --]
                [#if deploymentSubsetRequired("epilogue", false) && !cliCleanUpRequired ]
                    [@addToDefaultBashScriptOutput
                    content=
                        [
                            " case $\{STACK_OPERATION} in",
                            "   update|create)",
                            "       # Manage Scheduled Event",
                            "       info \"Removing scheduled rules created by cli...\""
                        ] +
                        ruleCleanupScript +
                        pseudoStackOutputScript(
                            "CLI Rule Cleanup",
                            ruleCleanupOutput
                        ) +
                        [
                            "       ;;",
                            " esac"
                        ]
                     /]
                [/#if]
            [/#if]
        [/#if]

        [#if solution.TaskLogGroup ]
            [#local lgId = resources["lg"].Id ]
            [#local lgName = resources["lg"].Name]
            [@setupLogGroup
                occurrence=subOccurrence
                logGroupId=lgId
                logGroupName=lgName
                loggingProfile=loggingProfile
            /]
        [/#if]

        [#list containers as container]
            [#if container.LogGroup?has_content]
                [#local lgId = container.LogGroup.Id ]
                    [@setupLogGroup
                        occurrence=subOccurrence
                        logGroupId=lgId
                        logGroupName=container.LogGroup.Name
                        loggingProfile=loggingProfile
                    /]
            [/#if]
        [/#list]

        [#list solution.Containers as id, container ]
            [#local imageSource = container.Image.Source]

            [#if deploymentSubsetRequired("pregeneration", false)
                    && imageSource == "containerregistry" ]
                [@addToDefaultBashScriptOutput
                    content=
                        getImageFromContainerRegistryScript(
                                productName,
                                environmentName,
                                segmentName,
                                subOccurrence,
                                container.Image["Source:containerregistry"].Image,
                                "docker",
                                getRegistryEndPoint("docker", subOccurrence),
                                "ecr",
                                regionId
                        )
                /]
            [/#if]
        [/#list]

        [#if deploymentSubsetRequired("ecs", true) ]

            [#list containers as container ]
                [#if container.LogGroup?has_content && container.LogMetrics?has_content ]
                    [#list container.LogMetrics as name,logMetric ]

                        [#local lgId = container.LogGroup.Id ]
                        [#local lgName = container.LogGroup.Name ]

                        [#local logMetricId = formatDependentLogMetricId(lgId, logMetric.Id)]

                        [#local containerLogMetricName = getCWMetricName(
                                logMetric.Name,
                                AWS_CLOUDWATCH_LOG_METRIC_RESOURCE_TYPE,
                                formatName(core.ShortFullName, container.Name) )]

                        [#local logFilter = logFilters[logMetric.LogFilter].Pattern ]

                        [#local resources += {
                            "logMetrics" : resources.LogMetrics!{} + {
                                "lgMetric" + name + container.Name : {
                                "Id" : formatDependentLogMetricId( lgId, logMetric.Id ),
                                "Name" : getCWMetricName( logMetric.Name, AWS_CLOUDWATCH_LOG_METRIC_RESOURCE_TYPE, containerLogMetricName ),
                                "Type" : AWS_CLOUDWATCH_LOG_METRIC_RESOURCE_TYPE,
                                "LogGroupName" : lgName,
                                "LogGroupId" : lgId,
                                "LogFilter" : logMetric.LogFilter
                                }
                            }
                        }]

                    [/#list]
                [/#if]
            [/#list]

            [#list resources.logMetrics!{} as logMetricName,logMetric ]

                [@createLogMetric
                    id=logMetric.Id
                    name=logMetric.Name
                    logGroup=logMetric.LogGroupName
                    filter=logFilters[logMetric.LogFilter].Pattern
                    namespace=getCWResourceMetricNamespace(logMetric.Type)
                    value=1
                    dependencies=logMetric.LogGroupId
                /]

            [/#list]

            [#list solution.Alerts?values as alert ]

                [#local monitoredResources = getCWMonitoredResources(core.Id, resources, alert.Resource)]
                [#list monitoredResources as name,monitoredResource ]

                    [#switch alert.Comparison ]
                        [#case "Threshold" ]
                            [@createAlarm
                                id=formatDependentAlarmId(monitoredResource.Id, alert.Id )
                                severity=alert.Severity
                                resourceName=core.FullName
                                alertName=alert.Name
                                actions=getCWAlertActions(subOccurrence, solution.Profiles.Alert, alert.Severity )
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
                                dimensions=getCWMetricDimensions(alert, monitoredResource, ( resources + { "cluster" : parentResources["cluster"] } ) )
                            /]
                        [#break]
                    [/#switch]
                [/#list]
            [/#list]

            [@createECSTask
                id=taskId
                name=taskName
                engine=engine
                containers=containers
                role=roleId
                executionRole=executionRoleId
                networkMode=networkMode
                dependencies=dependencies
                fixedName=solution.FixedName
            /]

        [/#if]

        [#if deploymentSubsetRequired("prologue", false)]
            [#-- Copy any asFiles needed by the task --]
            [#local asFiles = getAsFileSettings(subOccurrence.Configuration.Settings.Product) ]
            [#if asFiles?has_content]
                [@debug message="AsFiles" context=asFiles enabled=false /]
                [@addToDefaultBashScriptOutput
                    content=
                        findAsFilesScript("filesToSync", asFiles) +
                        syncFilesToBucketScript(
                            "filesToSync",
                            regionId,
                            operationsBucket,
                            getOccurrenceSettingValue(subOccurrence, "SETTINGS_PREFIX")
                        ) /]
            [/#if]
        [/#if]
    [/#list]
[/#macro]
