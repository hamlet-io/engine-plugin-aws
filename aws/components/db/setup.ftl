[#ftl]
[#macro aws_db_cf_deployment_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract
        subsets=["prologue", "template", "epilogue"]
        alternatives=[
            "primary",
            { "subset" : "template", "alternative" : "replace1"},
            { "subset" : "template", "alternative" : "replace2"}
        ]
    /]
[/#macro]

[#macro aws_db_cf_deployment_solution occurrence ]
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

    [#local auroraCluster = false]

    [#local engine = solution.Engine]
    [#local majorVersion = solution.EngineVersion]

    [#local multiAZ = solution.MultiAZ]

    [#-- If a minor version is provided, assume engine version is the major version --]
    [#-- Also disable minor version upgrades --]
    [#local minorVersion = solution.EngineMinorVersion!""]
    [#local autoMinorVersionUpgrade =
        (!minorVersion?has_content) &&
        solution.AutoMinorVersionUpgrade ]

    [#-- Default is that engine version = major version --]
    [#local engineVersion = concatenate([majorVersion, minorVersion],".")]

    [#switch engine]
        [#case "mysql"]
            [#break]

        [#case "postgres"]
            [#break]

        [#case "aurora-postgresql" ]
            [#local auroraCluster = true ]
            [#break]

        [#case "sqlserver-ee"]
        [#case "sqlserver-se"]
        [#case "sqlserver-ex"]
        [#case "sqlserver-web"]
            [#break]

        [#default]
            [@precondition
                function="solution_rds"
                context=occurrence
                detail="Unsupported engine provided"
            /]
            [#local engineVersion = "unknown" ]
            [#local family = "unknown" ]

            [#break]
    [/#switch]

    [#local credentialSource = solution["rootCredential:Source"] ]
    [#if isPresent(solution["rootCredential:Generated"]) && credentialSource != "Generated"]
        [#local credentialSource = "Generated"]
    [/#if]

    [#if auroraCluster ]
        [#local rdsId = resources["dbCluster"].Id ]
        [#local rdsFullName = resources["dbCluster"].Name ]
        [#local rdsClusterParameterGroupId = resources["dbClusterParamGroup"].Id ]
        [#local rdsClusterParameterGroupFamily = resources["dbClusterParamGroup"].Family ]
        [#local rdsClusterDbInstances = resources["dbInstances"]]

        [#local port = resources["dbCluster"].Port ]
    [#else]
        [#local rdsId = resources["db"].Id ]
        [#local rdsFullName = resources["db"].Name ]

        [#local port = resources["db"].Port ]
    [/#if]

    [#local portObject = ports[port] ]

    [#local hostType = attributes['TYPE'] ]
    [#local dbScheme = attributes['SCHEME']]

    [#local rdsSubnetGroupId = resources["subnetGroup"].Id ]
    [#local rdsParameterGroupId = resources["parameterGroup"].Id ]
    [#local rdsParameterGroupFamily = resources["parameterGroup"].Family ]
    [#local rdsOptionGroupId = resources["optionGroup"].Id ]

    [#local rdsSecurityGroupId = resources["securityGroup"].Id ]
    [#local rdsSecurityGroupName = resources["securityGroup"].Name ]

    [#local rdsDatabaseName = (engine?starts_with("sqlserver-"))?then(
            "",
            solution.DatabaseName!productName)]

    [#-- Root Credential Management --]
    [#switch credentialSource]
        [#case "Generated"]
            [#local passwordEncryptionScheme = (solution["rootCredential:Generated"].EncryptionScheme?has_content)?then(
                    solution["rootCredential:Generated"].EncryptionScheme?ensure_ends_with(":"),
                    "" )]

            [#local rdsUsername = solution["rootCredential:Generated"].Username]
            [#local rdsUsernameRef = rdsUsername]
            [#local rdsPasswordLength = solution["rootCredential:Generated"].CharacterLength]
            [#local rdsPassword = "DummyPassword" ]
            [#local rdsPasswordRef = rdsPassword]
            [#local rdsEncryptedPassword = (
                        getExistingReference(
                            rdsId,
                            GENERATEDPASSWORD_ATTRIBUTE_TYPE)
                        )?remove_beginning(
                            passwordEncryptionScheme
                        )]
            [#break]

        [#case "Settings"]
            [#local rdsUsername = attributes.USERNAME ]
            [#local rdsUsernameRef = rdsUsername]
            [#local rdsPassword = attributes.PASSWORD ]
            [#local rdsPasswordRef = rdsPassword]
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

                    [#local rdsUsername = solution["rootCredential:SecretStore"].Username ]
                    [#local rdsUsernameRef = getSecretManagerSecretRef(secretId, solution["rootCredential:SecretStore"].UsernameAttribute)]
                    [#local rdsPassword = ""]
                    [#local rdsPasswordRef = getSecretManagerSecretRef(secretId, solution["rootCredential:SecretStore"].PasswordAttribute)]
                    [#break]

                [#case SECRETSTORE_SECRET_COMPONENT_TYPE]
                    [#local secretId = secretLink.State.Resources["secret"].Id]

                    [#local rdsUsername = solution["rootCredential:SecretStore"].Username]
                    [#local rdsUsernameRef = getSecretManagerSecretRef(secretId, solution["rootCredential:SecretStore"].UsernameAttribute)]
                    [#local rdsPassword = ""]
                    [#local rdsPasswordRef = getSecretManagerSecretRef(secretId, solution["rootCredential:SecretStore"].PasswordAttribute)]

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

    [#local rdsRestoreSnapshot = getExistingReference(formatDependentRDSSnapshotId(rdsId), NAME_ATTRIBUTE_TYPE)]
    [#local rdsManualSnapshot = getExistingReference(formatDependentRDSManualSnapshotId(rdsId), NAME_ATTRIBUTE_TYPE)]
    [#local rdsLastSnapshot = getExistingReference(rdsId, LASTRESTORE_ATTRIBUTE_TYPE )]

    [#local backupTags = {} ]
    [#local links = getLinkTargets(occurrence, {}, false) ]
    [#list links as linkId,linkTarget]

        [#local linkTargetCore = linkTarget.Core ]
        [#local linkTargetConfiguration = linkTarget.Configuration ]
        [#local linkTargetResources = linkTarget.State.Resources ]
        [#local linkTargetAttributes = linkTarget.State.Attributes ]

        [#switch linkTargetCore.Type]
            [#case DATASET_COMPONENT_TYPE]
                [#if linkTargetConfiguration.Solution.Engine == "rds" ]
                    [#local rdsManualSnapshot = linkTargetAttributes["SNAPSHOT_NAME"] ]
                [/#if]
                [#break]

            [#case BACKUPSTORE_REGIME_COMPONENT_TYPE]
                [#if linkTargetAttributes["TAG_NAME"]?has_content]
                    [#local backupTags =
                        mergeObjects(
                            backupTags,
                            {
                                linkTargetAttributes["TAG_NAME"] : linkTargetAttributes["TAG_VALUE"]
                            }
                        )]
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

    [#local rdsPreDeploySnapshotId = formatName(
                                        rdsFullName,
                                        (getCLORunId())?split('')?reverse?join(''),
                                        "pre-deploy")]

    [#local rdsTags = getOccurrenceTags(occurrence)]

    [#local restoreSnapshotName = "" ]

    [#if hibernate && hibernateStartUpMode == "restore" ]
        [#local restoreSnapshotName = rdsPreDeploySnapshotId ]
    [/#if]

    [#local preDeploySnapshot = solution.Backup.SnapshotOnDeploy ||
                            ( hibernate && hibernateStartUpMode == "restore" ) ||
                            rdsManualSnapshot?has_content ]

    [#if solution.AlwaysCreateFromSnapshot ]
        [#if !rdsManualSnapshot?has_content ]
            [@fatal
                message="Snapshot must be provided to create this database"
                context=occurrence
                detail="Please provie a manual snapshot or a link to an RDS data set"
            /]
        [/#if]

        [#local restoreSnapshotName = rdsManualSnapshot ]
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

            [#if deploymentSubsetRequired("rds", true)]
                [@createSecurityGroupRulesFromLink
                    occurrence=occurrence
                    groupId=rdsSecurityGroupId
                    linkTarget=linkTarget
                    inboundPorts=[ port ]
                    networkProfile=networkProfile
                /]
            [/#if]

        [/#if]
    [/#list]

    [#if solution.Monitoring.DetailedMetrics.Enabled ]
        [#local monitoringRoleId = resources["monitoringRole"].Id ]
        [#if deploymentSubsetRequired("iam", true) && isPartOfCurrentDeploymentUnit(monitoringRoleId)]
            [@createRole
                id=monitoringRoleId
                trustedServices=[
                    "rds.amazonaws.com",
                    "monitoring.rds.amazonaws.com"
                ]
                managedArns=[
                    "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
                ]
                tags=getOccurrenceTags(occurrence)
            /]
        [/#if]
    [/#if]

    [#if deploymentSubsetRequired("prologue", false)]
        [@addToDefaultBashScriptOutput
            content=
            [
                "case $\{STACK_OPERATION} in",
                "  create|update)"
            ] +
            [#-- If a manual snapshot has been added the pseudo stack output should be replaced with an automated one --]
            (getExistingReference(rdsId)?has_content)?then(
                (rdsManualSnapshot?has_content)?then(
                    [
                        "# Check Snapshot Username",
                        "check_rds_snapshot_username" +
                        " \"" + getRegion() + "\" " +
                        " \"" + rdsManualSnapshot + "\" " +
                        " \"" + rdsUsername + "\" || return $?"
                    ],
                    []
                ) +
                preDeploySnapshot?then(
                    [
                        "# Create RDS snapshot",
                        "function create_deploy_snapshot() {",
                        "info \"Creating Pre-Deployment snapshot... \"",
                        "create_snapshot" +
                        " \"" + getRegion() + "\" " +
                        " \"" + hostType + "\" " +
                        " \"" + rdsFullName + "\" " +
                        " \"" + rdsPreDeploySnapshotId + "\" || return $?"
                    ] +
                    pseudoStackOutputScript(
                        "RDS Pre-Deploy Snapshot",
                        {
                            formatId("snapshot", rdsId, "name") : rdsPreDeploySnapshotId,
                            formatId("manualsnapshot", rdsId, "name") : ""
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
                        "# Encrypt RDS snapshot",
                        "function convert_plaintext_snapshot() {",
                        "info \"Checking Snapshot Encryption... \"",
                        "encrypt_snapshot" +
                        " \"" + getRegion() + "\" " +
                        " \"" + hostType + "\" " +
                        " \"" + rdsPreDeploySnapshotId + "\" " +
                        " \"" + cmkKeyArn + "\" || return $?",
                        "}",
                        "convert_plaintext_snapshot || return $?"
                    ],
                    []
                ),
                pseudoStackOutputScript(
                    "RDS Manual Snapshot Restore",
                    { formatId("manualsnapshot", rdsId, "name") : restoreSnapshotName }
                )
            ) +
            [
                " ;;",
                " esac"
            ]
        /]
    [/#if]

    [#if deploymentSubsetRequired("rds", true)]

        [@createSecurityGroup
            id=rdsSecurityGroupId
            name=rdsSecurityGroupName
            vpcId=vpcId
            tags=getOccurrenceTags(occurrence)
        /]

        [@createSecurityGroupRulesFromNetworkProfile
            occurrence=occurrence
            groupId=rdsSecurityGroupId
            networkProfile=networkProfile
            inboundPorts=[ port ]
        /]

        [#local ingressNetworkRule = {
                "Ports" : [ port ],
                "IPAddressGroups" : solution.IPAddressGroups
        }]

        [@createSecurityGroupIngressFromNetworkRule
            occurrence=occurrence
            groupId=rdsSecurityGroupId
            networkRule=ingressNetworkRule
        /]

        [@cfResource
            id=rdsSubnetGroupId
            type="AWS::RDS::DBSubnetGroup"
            properties=
                {
                    "DBSubnetGroupDescription" : rdsFullName,
                    "SubnetIds" : getSubnets(core.Tier, networkResources)
                }
            tags=rdsTags
            outputs={}
        /]

        [@cfResource
            id=rdsParameterGroupId
            type="AWS::RDS::DBParameterGroup"
            properties=
                {
                    "Family" : rdsParameterGroupFamily,
                    "Description" : rdsFullName,
                    "Parameters" : dbParameters
                }
            tags=rdsTags
            outputs={}
        /]

        [@cfResource
            id=rdsOptionGroupId
            type="AWS::RDS::OptionGroup"
            deletionPolicy="Retain"
            updateReplacePolicy="Retain"
            properties=
                {
                    "EngineName": engine,
                    "MajorEngineVersion": majorVersion,
                    "OptionGroupDescription" : rdsFullName,
                    "OptionConfigurations" : [
                    ]
                }
            tags=rdsTags
            outputs={}
        /]

        [#if auroraCluster ]

            [#local clusterParameters = {} ]
            [#list (solution.Cluster.Parameters)?values as parameter ]
                [#local clusterParameters += { parameter.Name : parameter.Value }]
            [/#list]

            [@cfResource
                id=rdsClusterParameterGroupId
                type="AWS::RDS::DBClusterParameterGroup"
                properties=
                    {
                        "Family" : rdsClusterParameterGroupFamily,
                        "Description" : rdsFullName,
                        "Parameters" : clusterParameters
                    }
                tags=rdsTags
                outputs={}
            /]
        [/#if]

        [#list (solution.Alerts?values)?filter(x -> x.Enabled) as alert ]

            [#local monitoredResources = getCWMonitoredResources(core.Id, resources, alert.Resource)]
            [#list monitoredResources as name,monitoredResource ]

                [@debug message="Monitored resource" context=monitoredResource enabled=false /]

                [#-- when replacing the instance the database is removed so we need to override refrences to keep the alarms around --]
                [#if monitoredResource.Id == rdsId &&
                        (getCLODeploymentUnitAlternative() == "replace1" || hibernate ) ]
                    [#local resourceDimensions = [
                        {
                            "Name": "DBInstanceIdentifier",
                            "Value": rdsFullName
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
                [#local rdsFullName=formatName(rdsFullName, "backup") ]
                [#if rdsManualSnapshot?has_content ]
                    [#local snapshotArn = rdsManualSnapshot ]
                [#else]
                    [#local snapshotArn = valueIfTrue(
                            rdsPreDeploySnapshotId,
                            solution.Backup.SnapshotOnDeploy,
                            rdsRestoreSnapshot)]
                [/#if]

                [#if solution.Backup.UpdateReplacePolicy == "Delete" ]
                    [#local hibernate = true ]
                [/#if]
            [#break]

            [#case "replace2"]
                [#if rdsManualSnapshot?has_content ]
                    [#local snapshotArn = rdsManualSnapshot ]
                [#else]
                [#local snapshotArn = valueIfTrue(
                        rdsPreDeploySnapshotId,
                        solution.Backup.SnapshotOnDeploy,
                        rdsRestoreSnapshot)]
                [/#if]
            [#break]

            [#default]
                [#if rdsManualSnapshot?has_content ]
                    [#local snapshotArn = rdsManualSnapshot ]
                [#else]
                    [#local snapshotArn = rdsLastSnapshot]
                [/#if]
        [/#switch]

        [#if !hibernate]

            [#if ! testMaintenanceWindow(solution.MaintenanceWindow)]
                [@fatal message="Maintenance window incorrectly configured" context=solution /]
                [#return]
            [/#if]

            [#if auroraCluster ]

                [#if solution.Cluster.ScalingPolicies?has_content &&
                        solution.Cluster.ScalingPolicies?values?map(x-> x.Enabled)?seq_contains(true) ]

                    [#local scalingTargetId = resources["scalingTarget"].Id ]
                    [#local serviceResourceType = resources["dbCluster"].Type ]

                    [#local processor = getProcessor(
                                            occurrence,
                                            DB_COMPONENT_TYPE,
                                            solution.ProcessorProfile)]
                    [#local processorCounts = getProcessorCounts(processor, multiAZ ) ]

                    [#local scheduledActions = []]
                    [#list solution.Cluster.ScalingPolicies as name, scalingPolicy ]
                        [#if scalingPolicy.Enabled ]
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

                                    [#local monitoredResources = getCWMonitoredResources(scalingTargetCore.Id, scalingTargetResources, scalingMetricTrigger.Resource)]

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
                                                                    DB_COMPONENT_TYPE,
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
                        [/#if]
                    [/#list]


                    [@createAutoScalingAppTarget
                        id=scalingTargetId
                        minCount=processorCounts.MinCount - auroraCluster?then(1,0)
                        maxCount=processorCounts.MaxCount - auroraCluster?then(1,0)
                        scalingResourceId=getAutoScalingRDSClusterResourceId(rdsId)
                        scalableDimension="rds:cluster:ReadReplicaCount"
                        resourceType=serviceResourceType
                        scheduledActions=scheduledActions
                    /]

                [/#if]

                [@createRDSCluster
                    id=rdsId
                    name=rdsFullName
                    engine=engine
                    engineVersion=engineVersion
                    port=portObject.Port
                    encrypted=solution.Encrypted
                    kmsKeyId=cmkKeyId
                    masterUsername=rdsUsernameRef
                    masterPassword=rdsPasswordRef
                    masterPasswordSource=(credentialSource == "SecretStore")?then("ssm", "cfnparam")
                    databaseName=rdsDatabaseName
                    retentionPeriod=solution.Backup.RetentionPeriod
                    subnetGroupId=getReference(rdsSubnetGroupId)
                    parameterGroupId=getReference(rdsClusterParameterGroupId)
                    snapshotArn=snapshotArn
                    securityGroupId=getReference(rdsSecurityGroupId)
                    tags=mergeObjects(rdsTags, backupTags)
                    deletionPolicy=deletionPolicy
                    updateReplacePolicy=updateReplacePolicy
                    maintenanceWindow=
                        solution.MaintenanceWindow.Configured?then(
                            getAmazonRdsMaintenanceWindow(
                                solution.MaintenanceWindow.DayOfTheWeek,
                                solution.MaintenanceWindow.TimeOfDay,
                                solution.MaintenanceWindow.TimeZone
                                ),
                            ""
                        )
                /]

                [#list solution.SystemNotifications as eventId, event ]
                    [#if (event.Categories?size > 1) && (event.Categories?seq_contains("_all"))]
                        [@fatal message="SystemNotification Category of _all cannot be included with other Categories" context=event /]
                    [/#if]
                    [#list event.Links as linkId, link ]
                        [#if link?is_hash]
                            [#local linkTarget = getLinkTarget(occurrence, link, false) ]
                            [@debug message="Link Target" context=linkTarget enabled=false /]

                            [#if !linkTarget?has_content]
                                [#continue]
                            [/#if]

                            [#local linkTargetCore = linkTarget.Core ]
                            [#local linkTargetConfiguration = linkTarget.Configuration ]
                            [#local linkTargetResources = linkTarget.State.Resources ]
                            [#local linkTargetAttributes = linkTarget.State.Attributes ]
                            [#local linkTargetSolution = linkTargetConfiguration.Solution]

                            [#if (link.Role+" ")?lower_case?starts_with("publish ") ]
                                [#if (event.Categories)?has_content]
                                    [#local linkRoles = event.Categories ]
                                [#else]
                                    [#local linkRoles = [] ]
                                [/#if]
                                [@createRDSEvent
                                    id=formatId(rdsId, eventId, linkId)
                                    rdsId=rdsId
                                    linkArn=linkTargetAttributes["ARN"]
                                    linkRoles=linkRoles
                                    sourceType="db-cluster"
                                /]
                            [/#if]
                        [/#if]
                    [/#list]
                [/#list]
                [#list resources["dbInstances"]?values as dbInstance ]
                    [@createRDSInstance
                        id=dbInstance.Id
                        name=dbInstance.Name
                        zoneId=dbInstance.ZoneId
                        engine=engine
                        processor=processorProfile.Processor
                        port=portObject.Port
                        subnetGroupId=rdsSubnetGroupId
                        parameterGroupId=rdsParameterGroupId
                        optionGroupId=rdsOptionGroupId
                        securityGroupId=rdsSecurityGroupId
                        caCertificate=requiredRDSCA
                        allowMajorVersionUpgrade=solution.AllowMajorVersionUpgrade
                        autoMinorVersionUpgrade=autoMinorVersionUpgrade
                        deleteAutomatedBackups=solution.Backup.DeleteAutoBackups
                        clusterMember=true
                        clusterId=rdsId
                        clusterPromotionTier=dbInstance?index
                        tags=rdsTags
                        deletionPolicy=""
                        updateReplacePolicy=""
                        kmsKeyId=cmkKeyId
                        enhancedMonitoring=solution.Monitoring.DetailedMetrics.Enabled
                        enhancedMonitoringInterval=solution.Monitoring.DetailedMetrics.CollectionInterval
                        enhancedMonitoringRoleId=monitoringRoleId!""
                        performanceInsights=solution.Monitoring.QueryPerformance.Enabled
                        performanceInsightsRetention=solution.Monitoring.QueryPerformance.RetentionPeriod
                        maintenanceWindow=
                            solution.MaintenanceWindow.Configured?then(
                                getAmazonRdsMaintenanceWindow(
                                    solution.MaintenanceWindow.DayOfTheWeek,
                                    solution.MaintenanceWindow.TimeOfDay,
                                    solution.MaintenanceWindow.TimeZone,
                                    dbInstance?counter
                                ),
                                ""
                            )
                    /]
                [/#list]

            [#else]
                [@createRDSInstance
                    id=rdsId
                    name=rdsFullName
                    engine=engine
                    engineVersion=engineVersion
                    processor=processorProfile.Processor
                    size=solution.Size
                    port=portObject.Port
                    multiAZ=multiAZ
                    zoneId=getZones()[0].Id
                    encrypted=solution.Encrypted
                    kmsKeyId=cmkKeyId
                    caCertificate=requiredRDSCA
                    masterUsername=rdsUsernameRef
                    masterPassword=rdsPasswordRef
                    masterPasswordSource=(credentialSource == "SecretStore")?then("ssm", "cfnparam")
                    databaseName=rdsDatabaseName
                    retentionPeriod=solution.Backup.RetentionPeriod
                    snapshotArn=snapshotArn
                    subnetGroupId=rdsSubnetGroupId
                    parameterGroupId=rdsParameterGroupId
                    optionGroupId=rdsOptionGroupId
                    securityGroupId=rdsSecurityGroupId
                    allowMajorVersionUpgrade=solution.AllowMajorVersionUpgrade
                    autoMinorVersionUpgrade=autoMinorVersionUpgrade
                    deleteAutomatedBackups=solution.Backup.DeleteAutoBackups
                    deletionPolicy=deletionPolicy
                    updateReplacePolicy=updateReplacePolicy
                    tags=mergeObjects(rdsTags, backupTags)
                    enhancedMonitoring=solution.Monitoring.DetailedMetrics.Enabled
                    enhancedMonitoringInterval=solution.Monitoring.DetailedMetrics.CollectionInterval
                    enhancedMonitoringRoleId=monitoringRoleId!""
                    performanceInsights=solution.Monitoring.QueryPerformance.Enabled
                    performanceInsightsRetention=solution.Monitoring.QueryPerformance.RetentionPeriod
                    maintenanceWindow=
                        solution.MaintenanceWindow.Configured?then(
                            getAmazonRdsMaintenanceWindow(
                                solution.MaintenanceWindow.DayOfTheWeek,
                                solution.MaintenanceWindow.TimeOfDay,
                                solution.MaintenanceWindow.TimeZone
                            ),
                            ""
                        )
                    /]
                [#list solution.SystemNotifications as eventId, event ]
                    [#if (event.Categories?size > 1) && (event.Categories?seq_contains("_all"))]
                        [@fatal message="SystemNotification Category of _all cannot be included with other Categories" context=event /]
                    [/#if]
                    [#list event.Links as linkId, link ]
                        [#if link?is_hash]
                            [#local linkTarget = getLinkTarget(occurrence, link, false) ]

                            [@debug message="Link Target" context=linkTarget enabled=false /]

                            [#if !linkTarget?has_content]
                                [#continue]
                            [/#if]

                            [#local linkTargetCore = linkTarget.Core ]
                            [#local linkTargetConfiguration = linkTarget.Configuration ]
                            [#local linkTargetResources = linkTarget.State.Resources ]
                            [#local linkTargetAttributes = linkTarget.State.Attributes ]
                            [#local linkTargetSolution = linkTargetConfiguration.Solution]

                            [#if (link.Role+" ")?lower_case?starts_with("publish ") ]
                                [#if (event.Categories)?has_content]
                                    [#local linkRoles = event.Categories ]
                                [#else]
                                    [#local linkRoles = [] ]
                                [/#if]
                                [@createRDSEvent
                                    id=formatId(rdsId, eventId, linkId)
                                    rdsId=rdsId
                                    linkArn=linkTargetAttributes["ARN"]
                                    linkRoles=linkRoles
                                    sourceType="db-instance"
                                /]
                            [/#if]
                        [/#if]
                    [/#list]
                [/#list]
            [/#if]
        [/#if]
    [/#if]

    [#if !hibernate ]
        [#if deploymentSubsetRequired("epilogue", false)]

            [#local rdsFQDN = getExistingReference(rdsId, DNS_ATTRIBUTE_TYPE)]
            [#local rdsCA = getExistingReference(rdsId, "ca")]

            [#local passwordPseudoStackFile = "\"$\{CF_DIR}/$(fileBase \"$\{BASH_SOURCE[0]}\")-password-pseudo-stack.json\"" ]
            [#local urlPseudoStackFile = "\"$\{CF_DIR}/$(fileBase \"$\{BASH_SOURCE[0]}\")-url-pseudo-stack.json\""]
            [#local caPseudoStackFile = "\"$\{CF_DIR}/$(fileBase \"$\{BASH_SOURCE[0]}\")-ca-pseudo-stack.json\""]
            [@addToDefaultBashScriptOutput
                content=
                [
                    "case $\{STACK_OPERATION} in",
                    "  create|update)"
                    "       rds_hostname=\"$(get_rds_hostname" +
                    "       \"" + getRegion() + "\" " +
                    "       \"" + hostType + "\" " +
                    "       \"" + rdsFullName + "\" || return $?)\""
                ] +
                auroraCluster?then(
                    [
                        "       rds_read_hostname=\"$(get_rds_hostname" +
                        "       \"" + getRegion() + "\" " +
                        "       \"" + hostType + "\" " +
                        "       \"" + rdsFullName + "\" " +
                        "       \"read\" || return $?)\""
                    ],
                    []
                ) +
                ( credentialSource == "Generated" && !(rdsEncryptedPassword?has_content))?then(
                    [
                        "# Generate Master Password",
                        "function generate_master_password() {",
                        "info \"Generating Master Password... \"",
                        "master_password=\"$(generateComplexString" +
                        " \"" + rdsPasswordLength + "\" )\"",
                        "encrypted_master_password=\"$(encrypt_kms_string" +
                        " \"" + getRegion() + "\" " +
                        " \"$\{master_password}\" " +
                        " \"" + cmkKeyArn + "\" || return $?)\"",
                        "info \"Setting Master Password... \"",
                        "set_rds_master_password" +
                        " \"" + getRegion() + "\" " +
                        " \"" + hostType + "\" " +
                        " \"" + rdsFullName + "\" " +
                        " \"$\{master_password}\" || return $?"
                    ] +
                    pseudoStackOutputScript(
                            "RDS Master Password",
                            { formatId(rdsId, "generatedpassword") : "$\{encrypted_master_password}" },
                            "password"
                    ) +
                    [
                        "info \"Generating URL... \"",
                        "rds_url=\"$(get_rds_url" +
                        " \"" + dbScheme + "\" " +
                        " \"" + rdsUsername + "\" " +
                        " \"$\{master_password}\" " +
                        " \"$\{rds_hostname}\" " +
                        " \"" + (portObject.Port)?c + "\" " +
                        " \"" + rdsDatabaseName + "\" || return $?)\"",
                        "encrypted_rds_url=\"$(encrypt_kms_string" +
                        " \"" + getRegion() + "\" " +
                        " \"$\{rds_url}\" " +
                        " \"" + cmkKeyArn + "\" || return $?)\""
                    ] +
                    auroraCluster?then(
                        [
                            "info \"Generating URL... \"",
                            "rds_read_url=\"$(get_rds_url" +
                            " \"" + dbScheme + "\" " +
                            " \"" + rdsUsername + "\" " +
                            " \"$\{master_password}\" " +
                            " \"$\{rds_read_hostname}\" " +
                            " \"" + (portObject.Port)?c + "\" " +
                            " \"" + rdsDatabaseName + "\" || return $?)\"",
                            "encrypted_rds_read_url=\"$(encrypt_kms_string" +
                            " \"" + getRegion() + "\" " +
                            " \"$\{rds_read_url}\" " +
                            " \"" + cmkKeyArn + "\" || return $?)\""
                        ],
                        []
                    ) +
                    pseudoStackOutputScript(
                            "RDS Connection URL",
                            { formatId(rdsId, "url") : "$\{encrypted_rds_url}" } +
                            auroraCluster?then(
                                { formatId(rdsId, "readurl") :  "$\{encrypted_rds_read_url}" },
                                {}
                            ),
                            "url"
                    ) +
                    [
                        "}",
                        "generate_master_password || return $?"
                    ],
                    []) +
                (rdsEncryptedPassword?has_content)?then(
                    [
                        "# Reset Master Password",
                        "function reset_master_password() {",
                        "info \"Getting Master Password... \"",
                        "encrypted_master_password=\"" + rdsEncryptedPassword + "\"",
                        "master_password=\"$(decrypt_kms_string" +
                        " \"" + getRegion() + "\" " +
                        " \"$\{encrypted_master_password}\" || return $?)\"",
                        "info \"Resetting Master Password... \"",
                        "set_rds_master_password" +
                        " \"" + getRegion() + "\" " +
                        " \"" + hostType + "\" " +
                        " \"" + rdsFullName + "\" " +
                        " \"$\{master_password}\" || return $?",
                        "info \"Generating URL... \"",
                        "rds_url=\"$(get_rds_url" +
                        " \"" + dbScheme + "\" " +
                        " \"" + rdsUsername + "\" " +
                        " \"$\{master_password}\" " +
                        " \"$\{rds_hostname}\" " +
                        " \"" + (portObject.Port)?c + "\" " +
                        " \"" + rdsDatabaseName + "\" || return $?)\"",
                        "encrypted_rds_url=\"$(encrypt_kms_string" +
                        " \"" + getRegion() + "\" " +
                        " \"$\{rds_url}\" " +
                        " \"" + cmkKeyArn + "\" || return $?)\""
                    ] +
                    auroraCluster?then(
                        [
                            "info \"Generating URL... \"",
                            "rds_read_url=\"$(get_rds_url" +
                            " \"" + dbScheme + "\" " +
                            " \"" + rdsUsername + "\" " +
                            " \"$\{master_password}\" " +
                            " \"$\{rds_read_hostname}\" " +
                            " \"" + (portObject.Port)?c + "\" " +
                            " \"" + rdsDatabaseName + "\" || return $?)\"",
                            "encrypted_rds_read_url=\"$(encrypt_kms_string" +
                            " \"" + getRegion() + "\" " +
                            " \"$\{rds_read_url}\" " +
                            " \"" + cmkKeyArn + "\" || return $?)\""
                        ],
                        []
                    ) +
                    pseudoStackOutputScript(
                            "RDS Connection URL",
                            { formatId(rdsId, "url") : "$\{encrypted_rds_url}" } +
                            auroraCluster?then(
                                { formatId(rdsId, "readurl") :  "$\{encrypted_rds_read_url}" },
                                {}
                            ),
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
