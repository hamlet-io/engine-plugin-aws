[#ftl]
[#macro aws_docdb_cf_deployment_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract
        subsets=["prologue", "template", "epilogue"]
        alternatives=[
            "primary",
            { "subset" : "template", "alternative" : "replace1"},
            { "subset" : "template", "alternative" : "replace2"}
        ]
    /]
[/#macro]

[#macro aws_docdb_cf_deployment_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]
    [#local attributes = occurrence.State.Attributes ]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "Encryption" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local cmkKeyId = baselineComponentIds["Encryption"]!"" ]
    [#local cmkKeyArn = getReference(cmkKeyId, ARN_ATTRIBUTE_TYPE)]

    [#local networkLink = getOccurrenceNetwork(occurrence).Link!{} ]
    [#local networkLinkTarget = getLinkTarget(occurrence, networkLink ) ]
    [#if ! networkLinkTarget?has_content ]
        [@fatal message="Network could not be found" context=networkLink /]
        [#return]
    [/#if]
    [#local networkConfiguration = networkLinkTarget.Configuration.Solution]
    [#local networkResources = networkLinkTarget.State.Resources ]
    [#local vpcId = networkResources["vpc"].Id ]

    [#local engineVersion = solution.EngineVersion]

    [#local credentialSource = solution["rootCredential:Source"] ]
    [#if isPresent(solution["rootCredential:Generated"]) && credentialSource != "Generated"]
        [#local credentialSource = "Generated"]
    [/#if]

    [#local ddsId = resources["dbCluster"].Id ]
    [#local ddsFullName = resources["dbCluster"].Name ]
    [#local ddsClusterParameterGroupId = resources["dbClusterParamGroup"].Id ]
    [#local ddsClusterParameterGroupFamily = resources["dbClusterParamGroup"].Family ]
    [#local ddsClusterDbInstances = resources["dbInstances"]]

    [#local port = resources["dbCluster"].Port ]

    [#local portObject = ports[port] ]

    [#local hostType = attributes['TYPE'] ]
    [#local ddsSubnetGroupId = resources["subnetGroup"].Id ]
    [#local ddsParameterGroupId = resources["parameterGroup"].Id ]
    [#local ddsParameterGroupFamily = resources["parameterGroup"].Family ]

    [#local ddsSecurityGroupId = resources["securityGroup"].Id ]
    [#local ddsSecurityGroupName = resources["securityGroup"].Name ]

    [#-- Root Credential Management --]
    [#switch credentialSource]
        [#case "Generated"]
            [#local passwordEncryptionScheme = (solution["rootCredential:Generated"].EncryptionScheme?has_content)?then(
                    solution["rootCredential:Generated"].EncryptionScheme?ensure_ends_with(":"),
                    "" )]

            [#local ddsUsername = solution["rootCredential:Generated"].Username]
            [#local ddsUsernameRef = ddsUsername]
            [#local ddsPasswordLength = solution["rootCredential:Generated"].CharacterLength]
            [#local ddsPassword = "DummyPassword" ]
            [#local ddsPasswordRef = ddsPassword]
            [#local ddsEncryptedPassword = (
                        getExistingReference(
                            ddsId,
                            GENERATEDPASSWORD_ATTRIBUTE_TYPE)
                        )?remove_beginning(
                            passwordEncryptionScheme
                        )]
            [#break]

        [#case "Settings"]
            [#local ddsUsername = attributes.USERNAME ]
            [#local ddsUsernameRef = ddsUsername]
            [#local ddsPassword = attributes.PASSWORD ]
            [#local ddsPasswordRef = ddsPassword]
            [#break]

        [#case "SecretStore"]
            [#local secretLink = getLinkTarget(occurrence, (solution["rootCredential:SecretStore"].Link)!{}, true, true) ]

            [#switch (secretLink.Core.Type)!"" ]

                [#case SECRETSTORE_COMPONENT_TYPE]
                    [@setupComponentGeneratedSecret
                        occurrence=occurrence
                        secretStoreLink=secretLink
                        kmsKeyId=cmkKeyId
                        secretComponentResources=resources["rootCredentials"]
                        secretComponentConfiguration=
                            {
                                "Requirements" : solution["rootCredential:SecretStore"].GenerationRequirements,
                                "Generated" : {
                                    "Content" : {
                                        solution["rootCredential:SecretStore"].UsernameAttribute : solution["rootCredential:SecretStore"].Username
                                    },
                                    "SecretKey" : solution["rootCredential:SecretStore"].PasswordAttribute
                                }
                            }
                        componentType=DIRECTORY_COMPONENT_TYPE
                    /]

                    [#local secretId = resources["rootCredentials"]["secret"].Id ]

                    [#local ddsUsername = solution["rootCredential:SecretStore"].Username ]
                    [#local ddsUsernameRef = getSecretManagerSecretRef(secretId, solution["rootCredential:SecretStore"].UsernameAttribute)]
                    [#local ddsPassword = ""]
                    [#local ddsPasswordRef = getSecretManagerSecretRef(secretId, solution["rootCredential:SecretStore"].PasswordAttribute)]
                    [#break]

                [#case SECRETSTORE_SECRET_COMPONENT_TYPE]
                    [#local secretId = secretLink.State.Resources["secret"].Id]

                    [#local ddsUsername = solution["rootCredential:SecretStore"].Username]
                    [#local ddsUsernameRef = getSecretManagerSecretRef(secretId, solution["rootCredential:SecretStore"].UsernameAttribute)]
                    [#local ddsPassword = ""]
                    [#local ddsPasswordRef = getSecretManagerSecretRef(secretId, solution["rootCredential:SecretStore"].PasswordAttribute)]

                    [#break]

                [#default]
                    [@fatal
                        message="Invalid secretLink for db credentials"
                        context={
                            "Id" : core.RawId,
                            "SecretLink" : solution["rootCredential:SecretStore"].Link,
                            "SecretLinkComponentType" : (secretLink.Core.Type)!""
                        }
                    /]

            [/#switch]
            [#break]
    [/#switch]

    [#local hibernate = solution.Hibernate.Enabled && isOccurrenceDeployed(occurrence)]

    [#local hibernateStartUpMode = solution.Hibernate.StartUpMode ]

    [#local ddsRestoreSnapshot = getExistingReference(formatDependentRDSSnapshotId(ddsId), NAME_ATTRIBUTE_TYPE)]
    [#local ddsManualSnapshot = getExistingReference(formatDependentRDSManualSnapshotId(ddsId), NAME_ATTRIBUTE_TYPE)]
    [#local ddsLastSnapshot = getExistingReference(ddsId, LASTRESTORE_ATTRIBUTE_TYPE )]

    [#local backupTags = [] ]
    [#local links = getLinkTargets(occurrence, {}, false) ]
    [#list links as linkId,linkTarget]

        [#local linkTargetCore = linkTarget.Core ]
        [#local linkTargetConfiguration = linkTarget.Configuration ]
        [#local linkTargetResources = linkTarget.State.Resources ]
        [#local linkTargetAttributes = linkTarget.State.Attributes ]

        [#switch linkTargetCore.Type]
            [#case BACKUPSTORE_REGIME_COMPONENT_TYPE]
                [#if linkTargetAttributes["TAG_NAME"]?has_content]
                    [#local backupTags +=
                        [
                            {
                                "Key" : linkTargetAttributes["TAG_NAME"],
                                "Value" : linkTargetAttributes["TAG_VALUE"]
                            }
                        ]
                    ]
                [#else]
                    [@warn
                        message="Ignoring linked backup regime \"${linkTargetCore.SubComponent.Name}\" that does not support tag based inclusion"
                        context=linkTargetCore
                    /]
                [/#if]
                [#break]
        [/#switch]
    [/#list]

    [#local deletionPolicy = solution.Backup.DeletionPolicy]
    [#local updateReplacePolicy = solution.Backup.UpdateReplacePolicy]

    [#local ddsPreDeploySnapshotId = formatName(
                                        ddsFullName,
                                        (getCLORunId())?split('')?reverse?join(''),
                                        "pre-deploy")]

    [#local ddsTags = getOccurrenceCoreTags(occurrence, ddsFullName)]

    [#local restoreSnapshotName = "" ]

    [#if hibernate && hibernateStartUpMode == "restore" ]
        [#local restoreSnapshotName = ddsPreDeploySnapshotId ]
    [/#if]

    [#local preDeploySnapshot = solution.Backup.SnapshotOnDeploy ||
                            ( hibernate && hibernateStartUpMode == "restore" ) ||
                            ddsManualSnapshot?has_content ]

    [#if solution.AlwaysCreateFromSnapshot ]
        [#if !ddsManualSnapshot?has_content ]
            [@fatal
                message="Snapshot must be provided to create this database"
                context=occurrence
                detail="Please provie a manual snapshot or a link to an RDS data set"
            /]
        [/#if]

        [#local restoreSnapshotName = ddsManualSnapshot ]
        [#local preDeploySnapshot = false ]

    [/#if]

    [#local dbParameters = {} ]
    [#list solution.DBParameters as key,value ]
        [#if key != "Name" && key != "Id" ]
            [#local dbParameters += { key : value }]
        [/#if]
    [/#list]

    [#local processorProfile    = getProcessor(occurrence, core.Type )]
    [#local networkProfile      = getNetworkProfile(occurrence)]
    [#local securityProfile     = getSecurityProfile(occurrence, core.Type )]
    [#local requiredRDSCA       = securityProfile["SSLCertificateAuthority"]!"HamletFatal: SSLCertificateAuthority not found in security profile: " + solution.Profiles.Security ]

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

            [#if deploymentSubsetRequired(DOCDB_COMPONENT_TYPE, true)]
                [@createSecurityGroupRulesFromLink
                    occurrence=occurrence
                    groupId=ddsSecurityGroupId
                    linkTarget=linkTarget
                    inboundPorts=[ port ]
                    networkProfile=networkProfile
                /]
            [/#if]

        [/#if]
    [/#list]

    [#if deploymentSubsetRequired("prologue", false)]
        [@addToDefaultBashScriptOutput
            content=
            [
                "case $\{STACK_OPERATION} in",
                "  create|update)"
            ] +
            [#-- If a manual snapshot has been added the pseudo stack output should be replaced with an automated one --]
            (getExistingReference(ddsId)?has_content)?then(
                (ddsManualSnapshot?has_content)?then(
                    [
                        "# Check Snapshot Username",
                        "check_dds_snapshot_username" +
                        " \"" + getRegion() + "\" " +
                        " \"" + ddsManualSnapshot + "\" " +
                        " \"" + ddsUsername + "\" || return $?"
                    ],
                    []
                ) +
                preDeploySnapshot?then(
                    [
                        "# Create DDS snapshot",
                        "function create_deploy_snapshot() {",
                        "info \"Creating Pre-Deployment snapshot... \"",
                        "create_dds_snapshot" +
                        " \"" + getRegion() + "\" " +
                        " \"" + ddsFullName + "\" " +
                        " \"" + ddsPreDeploySnapshotId + "\" || return $?"
                    ] +
                    pseudoStackOutputScript(
                        "DDS Pre-Deploy Snapshot",
                        {
                            formatId("snapshot", ddsId, "name") : ddsPreDeploySnapshotId,
                            formatId("manualsnapshot", ddsId, "name") : ""
                        }
                    ) +
                    [
                        "}",
                        "create_deploy_snapshot || return $?"
                    ],
                    []) +
                (( solution.Backup.SnapshotOnDeploy ||
                    ( hibernate && hibernateStartUpMode == "restore" ) )
                    && solution.Encrypted)?then(
                    [
                        "# Encrypt DDS snapshot",
                        "function convert_plaintext_snapshot() {",
                        "info \"Checking Snapshot Encryption... \"",
                        "encrypt_dds_snapshot" +
                        " \"" + getRegion() + "\" " +
                        " \"" + ddsPreDeploySnapshotId + "\" " +
                        " \"" + cmkKeyArn + "\" || return $?",
                        "}",
                        "convert_plaintext_snapshot || return $?"
                    ],
                    []
                ),
                pseudoStackOutputScript(
                    "DDS Manual Snapshot Restore",
                    { formatId("manualsnapshot", ddsId, "name") : restoreSnapshotName }
                )
            ) +
            [
                " ;;",
                " esac"
            ]
        /]
    [/#if]

    [#if deploymentSubsetRequired(DOCDB_COMPONENT_TYPE, true)]

        [@createSecurityGroup
            id=ddsSecurityGroupId
            name=ddsSecurityGroupName
            vpcId=vpcId
            occurrence=occurrence
        /]

        [@createSecurityGroupRulesFromNetworkProfile
            occurrence=occurrence
            groupId=ddsSecurityGroupId
            networkProfile=networkProfile
            inboundPorts=[ port ]
        /]

        [#local ingressNetworkRule = {
                "Ports" : [ port ],
                "IPAddressGroups" : solution.IPAddressGroups
        }]

        [@createSecurityGroupIngressFromNetworkRule
            occurrence=occurrence
            groupId=ddsSecurityGroupId
            networkRule=ingressNetworkRule
        /]

        [@cfResource
            id=ddsSubnetGroupId
            type="AWS::DocDB::DBSubnetGroup"
            properties=
                {
                    "DBSubnetGroupDescription" : ddsFullName,
                    "SubnetIds" : getSubnets(core.Tier, networkResources)
                }
            tags=ddsTags
            outputs={}
        /]

        [#local clusterParameters = {} ]
        [#list (solution.Cluster.Parameters)?values as parameter ]
            [#local clusterParameters += { parameter.Name : parameter.Value }]
        [/#list]

        [@cfResource
            id=ddsClusterParameterGroupId
            type="AWS::DocDB::DBClusterParameterGroup"
            properties=
                {
                    "Family" : ddsClusterParameterGroupFamily,
                    "Description" : ddsFullName,
                    "Parameters" : clusterParameters
                }
            tags=ddsTags
            outputs={}
        /]

        [#list (solution.Alerts?values)?filter(x -> x.Enabled) as alert ]

            [#local monitoredResources = getCWMonitoredResources(core.Id, resources, alert.Resource)]
            [#list monitoredResources as name,monitoredResource ]

                [@debug message="Monitored resource" context=monitoredResource enabled=false /]

                [#-- when replacing the instance the database is removed so we need to override refrences to keep the alarms around --]
                [#if monitoredResource.Id == ddsId &&
                        (getCLODeploymentUnitAlternative() == "replace1" || hibernate ) ]
                    [#local resourceDimensions = [
                        {
                            "Name": "DBInstanceIdentifier",
                            "Value": ddsFullName
                        }
                    ]]
                [#else]
                    [#local resourceDimensions = getCWMetricDimensions(alert, monitoredResource, resources) ]
                [/#if]

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
                            dimensions=resourceDimensions
                        /]
                    [#break]
                [/#switch]
            [/#list]
        [/#list]

        [#switch getCLODeploymentUnitAlternative() ]
            [#case "replace1" ]
                [#local multiAZ = false]
                [#local deletionPolicy = "Delete" ]
                [#local updateReplacePolicy = "Delete" ]
                [#local ddsFullName=formatName(ddsFullName, "backup") ]
                [#if ddsManualSnapshot?has_content ]
                    [#local snapshotArn = ddsManualSnapshot ]
                [#else]
                    [#local snapshotArn = valueIfTrue(
                            ddsPreDeploySnapshotId,
                            solution.Backup.SnapshotOnDeploy,
                            ddsRestoreSnapshot)]
                [/#if]

                [#if solution.Backup.UpdateReplacePolicy == "Delete" ]
                    [#local hibernate = true ]
                [/#if]
            [#break]

            [#case "replace2"]
                [#if ddsManualSnapshot?has_content ]
                    [#local snapshotArn = ddsManualSnapshot ]
                [#else]
                [#local snapshotArn = valueIfTrue(
                        ddsPreDeploySnapshotId,
                        solution.Backup.SnapshotOnDeploy,
                        ddsRestoreSnapshot)]
                [/#if]
            [#break]

            [#default]
                [#if ddsManualSnapshot?has_content ]
                    [#local snapshotArn = ddsManualSnapshot ]
                [#else]
                    [#local snapshotArn = ddsLastSnapshot]
                [/#if]
        [/#switch]

        [#if !hibernate]

            [#if ! testMaintenanceWindow(solution.MaintenanceWindow)]
                [@fatal message="Maintenance window incorrectly configured" context=solution /]
                [#return]
            [/#if]

            [#if solution.Cluster.ScalingPolicies?has_content ]
                [#local scalingTargetId = resources["scalingTarget"].Id ]
                [#local serviceResourceType = resources["dbCluster"].Type ]

                [#local processor = getProcessor(
                                        occurrence,
                                        core.Type,
                                        solution.ProcessorProfile)]
                [#local processorCounts = getProcessorCounts(processor, multiAZ ) ]

                [#local scheduledActions = []]
                [#list solution.Cluster.ScalingPolicies as name, scalingPolicy ]
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
                                [#local scalingTargetResources = resources ]
                            [/#if]

                            [#local monitoredResources = getCWMonitoredResources(scalingTargetResources, scalingMetricTrigger.Resource)]

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

                            [#if scalingMetricTrigger.Configured ]
                                [#local metricName = getCWMetricName(scalingMetricTrigger.Metric, monitoredResource.Type, scalingTargetCore.ShortFullName)]
                                [#local metricNamespace = getCWResourceMetricNamespace(monitoredResource.Type)]
                            [/#if]

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
                                [#else]
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
                                                            occurrence,
                                                            core.Type,
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
                    scalingResourceId=getAutoScalingRDSClusterResourceId(ddsId)
                    scalableDimension="dds:cluster:ReadReplicaCount"
                    resourceType=serviceResourceType
                    scheduledActions=scheduledActions
                /]

            [/#if]

            [@createDDSCluster
                id=ddsId
                name=ddsFullName
                engineVersion=engineVersion
                port=portObject.Port
                encrypted=solution.Encrypted
                kmsKeyId=cmkKeyId
                masterUsername=ddsUsernameRef
                masterPassword=ddsPasswordRef
                retentionPeriod=solution.Backup.RetentionPeriod
                subnetGroupId=getReference(ddsSubnetGroupId)
                parameterGroupId=getReference(ddsClusterParameterGroupId)
                snapshotArn=snapshotArn
                securityGroupId=getReference(ddsSecurityGroupId)
                tags=ddsTags
                deletionPolicy=deletionPolicy
                updateReplacePolicy=updateReplacePolicy
                maintenanceWindow=
                    solution.MaintenanceWindow.Configured?then(
                        getAmazonDdsMaintenanceWindow(
                            solution.MaintenanceWindow.DayOfTheWeek,
                            solution.MaintenanceWindow.TimeOfDay,
                            solution.MaintenanceWindow.TimeZone
                            ),
                        ""
                    )
                backupWindow=
                    solution.Backup.BackupWindow.Configured?then(
                        getAmazonDdsBackupWindow(
                            solution.Backup.BackupWindow.TimeOfDay,
                            solution.Backup.BackupWindow.TimeZone
                            ),
                        ""
                    )
            /]

            [#list resources["dbInstances"]?values as dbInstance ]
                [@createDDSInstance
                    id=dbInstance.Id
                    name=dbInstance.Name
                    zoneId=dbInstance.ZoneId
                    processor=processorProfile.Processor
                    clusterId=ddsId
                    tags=ddsTags
                    deletionPolicy=""
                    updateReplacePolicy=""
                    maintenanceWindow=
                        solution.MaintenanceWindow.Configured?then(
                            getAmazonDdsMaintenanceWindow(
                                solution.MaintenanceWindow.DayOfTheWeek,
                                solution.MaintenanceWindow.TimeOfDay,
                                solution.MaintenanceWindow.TimeZone,
                                dbInstance?counter
                            ),
                            ""
                        )
                /]
            [/#list]
        [/#if]
    [/#if]

    [#if !hibernate ]
        [#if deploymentSubsetRequired("epilogue", false)]

            [#local ddsFQDN = getExistingReference(ddsId, DNS_ATTRIBUTE_TYPE)]
            [#local ddsCA = getExistingReference(ddsId, "ca")]

            [#local passwordPseudoStackFile = "\"$\{CF_DIR}/$(fileBase \"$\{BASH_SOURCE}\")-password-pseudo-stack.json\"" ]
            [#local urlPseudoStackFile = "\"$\{CF_DIR}/$(fileBase \"$\{BASH_SOURCE}\")-url-pseudo-stack.json\""]
            [#local caPseudoStackFile = "\"$\{CF_DIR}/$(fileBase \"$\{BASH_SOURCE}\")-ca-pseudo-stack.json\""]
            [@addToDefaultBashScriptOutput
                content=
                [
                    "case $\{STACK_OPERATION} in",
                    "  create|update)"
                    "       dds_hostname=\"$(get_dds_hostname" +
                    "       \"" + getRegion() + "\" " +
                    "       \"" + ddsFullName + "\" || return $?)\""
                ] +
                [
                    "       dds_read_hostname=\"$(get_dds_hostname" +
                    "       \"" + getRegion() + "\" " +
                    "       \"" + ddsFullName + "\" " +
                    "       \"read\" || return $?)\""
                ] +
                ( credentialSource == "Generated" && !(ddsEncryptedPassword?has_content))?then(
                    [
                        "# Generate Master Password",
                        "function generate_master_password() {",
                        "info \"Generating Master Password... \"",
                        "master_password=\"$(generateComplexString" +
                        " \"" + ddsPasswordLength + "\" )\"",
                        "encrypted_master_password=\"$(encrypt_kms_string" +
                        " \"" + getRegion() + "\" " +
                        " \"$\{master_password}\" " +
                        " \"" + cmkKeyArn + "\" || return $?)\"",
                        "info \"Setting Master Password... \"",
                        "set_dds_master_password" +
                        " \"" + getRegion() + "\" " +
                        " \"" + ddsFullName + "\" " +
                        " \"$\{master_password}\" || return $?"
                    ] +
                    pseudoStackOutputScript(
                            "RDS Master Password",
                            { formatId(ddsId, "generatedpassword") : "$\{encrypted_master_password}" },
                            "password"
                    ) +
                    [
                        "info \"Generating URL... \"",
                        "dds_url=\"$(get_dds_url" +
                        " \"mongodb\" " +
                        " \"" + ddsUsername + "\" " +
                        " \"$\{master_password}\" " +
                        " \"$\{dds_hostname}\" " +
                        " \"" + (portObject.Port)?c + "\" || return $?)\" ",
                        "encrypted_dds_url=\"$(encrypt_kms_string" +
                        " \"" + getRegion() + "\" " +
                        " \"$\{dds_url}\" " +
                        " \"" + cmkKeyArn + "\" || return $?)\""
                    ] +
                    [
                        "info \"Generating URL... \"",
                        "dds_read_url=\"$(get_dds_url" +
                        " \"mongodb\" " +
                        " \"" + ddsUsername + "\" " +
                        " \"$\{master_password}\" " +
                        " \"$\{dds_read_hostname}\" " +
                        " \"" + (portObject.Port)?c + "\" || return $?)\" ",
                        "encrypted_dds_read_url=\"$(encrypt_kms_string" +
                        " \"" + getRegion() + "\" " +
                        " \"$\{dds_read_url}\" " +
                        " \"" + cmkKeyArn + "\" || return $?)\""
                    ] +
                    pseudoStackOutputScript(
                            "RDS Connection URL",
                            { formatId(ddsId, "url") : "$\{encrypted_dds_url}" } +
                            { formatId(ddsId, "readurl") :  "$\{encrypted_dds_read_url}" },
                            "url"
                    ) +
                    [
                        "}",
                        "generate_master_password || return $?"
                    ],
                    []) +
                (ddsEncryptedPassword?has_content)?then(
                    [
                        "# Reset Master Password",
                        "function reset_master_password() {",
                        "info \"Getting Master Password... \"",
                        "encrypted_master_password=\"" + ddsEncryptedPassword + "\"",
                        "master_password=\"$(decrypt_kms_string" +
                        " \"" + getRegion() + "\" " +
                        " \"$\{encrypted_master_password}\" || return $?)\"",
                        "info \"Resetting Master Password... \"",
                        "set_dds_master_password" +
                        " \"" + getRegion() + "\" " +
                        " \"" + ddsFullName + "\" " +
                        " \"$\{master_password}\" || return $?",
                        "info \"Generating URL... \"",
                        "dds_url=\"$(get_dds_url" +
                        " \"mongodb\" " +
                        " \"" + ddsUsername + "\" " +
                        " \"$\{master_password}\" " +
                        " \"$\{dds_hostname}\" " +
                        " \"" + (portObject.Port)?c + "\" || return $?)\" ",
                        "encrypted_dds_url=\"$(encrypt_kms_string" +
                        " \"" + getRegion() + "\" " +
                        " \"$\{dds_url}\" " +
                        " \"" + cmkKeyArn + "\" || return $?)\""
                    ] +
                    [
                        "info \"Generating URL... \"",
                        "dds_read_url=\"$(get_dds_url" +
                        " \"mongodb\" " +
                        " \"" + ddsUsername + "\" " +
                        " \"$\{master_password}\" " +
                        " \"$\{dds_read_hostname}\" " +
                        " \"" + (portObject.Port)?c + "\" || return $?)\" ",
                        "encrypted_dds_read_url=\"$(encrypt_kms_string" +
                        " \"" + getRegion() + "\" " +
                        " \"$\{dds_read_url}\" " +
                        " \"" + cmkKeyArn + "\" || return $?)\""
                    ] +
                    pseudoStackOutputScript(
                            "RDS Connection URL",
                            { formatId(ddsId, "url") : "$\{encrypted_dds_url}" } +
                            { formatId(ddsId, "readurl") :  "$\{encrypted_dds_read_url}" },
                            "url"
                    ) +
                    [
                        "}",
                        "reset_master_password || return $?"
                    ],
                []) +
                [
                    "       ;;",
                    "       esac"
                ]
            /]
        [/#if]
    [/#if]
[/#macro]
