[#ftl]
[#macro aws_es_cf_deployment_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract subsets=["deploymentcontract", "template", "epilogue" ] /]
[/#macro]

[#macro aws_es_cf_deployment_deploymentcontract occurrence ]
    [@addDefaultAWSDeploymentContract epilogue=true /]
[/#macro]

[#macro aws_es_cf_deployment_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]
    [#local resources = occurrence.State.Resources]
    [#local roles = occurrence.State.Roles]

    [#local esId = resources["es"].Id]
    [#local esName = resources["es"].Name]
    [#local esHostName = (resources["es"].customHostName)!"" ]
    [#local esServiceRoleId = resources["servicerole"].Id]
    [#local esSnapshotRoleId = resources["snapshotrole"].Id]

    [#local certificate = (resources["certificate"])!{}]

    [#local lgId = (resources["lg"].Id)!"" ]
    [#local lgName = (resources["lg"].Name)!"" ]

    [#local vpcAccess = solution.VPCAccess]

    [#local multiAZ = solution.MultiAZ]

    [#local securityProfile = getSecurityProfile(occurrence, core.Type)]

    [#local networkConfiguration = {} ]
    [#if vpcAccess ]
        [#local networkLink = getOccurrenceNetwork(occurrence).Link!{} ]
        [#local networkLinkTarget = getLinkTarget(occurrence, networkLink ) ]
        [#if ! networkLinkTarget?has_content ]
            [@fatal message="Network could not be found" context=networkLink /]
            [#return]
        [/#if]
        [#local networkConfiguration = networkLinkTarget.Configuration.Solution]
        [#local networkResources = networkLinkTarget.State.Resources ]
        [#local vpcId = networkResources["vpc"].Id ]
        [#local subnets = getSubnets(core.Tier, networkResources) ]

        [#local sgId = resources["sg"].Id ]
        [#local sgName = resources["sg"].Name ]
        [#local ports = resources["sg"].Ports ]

        [#local networkProfile = getNetworkProfile(occurrence)]

        [#local networkConfiguration = {
                    "SecurityGroupIds" : [ getReference(sgId) ],
                    "SubnetIds" : valueIfTrue(
                                    subnets,
                                    multiAZ,
                                    [ subnets[0] ]
                    )
                }]

        [#if ! isServiceLinkedRoleDeployed("es.amazonaws.com") ]
            [@fatal
                message="es.amazonaws.com service linked role not deployed"
                detail="Run an account level iam deployment to enable the service"
            /]
        [/#if]
    [/#if]

    [#local loggingProfile = getLoggingProfile(occurrence)]

    [#if solution.Logging &&
            ! getExistingReference(formatAccountResourceId(AWS_CLOUDWATCH_LOG_RESOURCE_POLICY_RESOURCE_TYPE, "es"))?has_content ]
        [@fatal
            message="Account level CloudWatch access policy required for logging"
            detail="Run an account level deployment for the es deployment unit"
        /]
    [/#if]

    [#local processorProfile = getProcessor(occurrence, ES_COMPONENT_TYPE)]
    [#local dataNodeCount = multiAZ?then(
                                    processorProfile.CountPerZone * getZones()?size,
                                    processorProfile.CountPerZone
                            )]

    [#local master = processorProfile.Master!{}]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "OpsData", "AppData", "Encryption", "SSHKey" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local cmkKeyId = baselineComponentIds["Encryption"] ]

    [#local esAuthentication = solution.Authentication]

    [#local cognitoIntegration = false ]
    [#local cognitoConfig = {
            "Enabled" : false,
            "RoleArn" : getReference(esServiceRoleId, ARN_ATTRIBUTE_TYPE)
    }]

    [#local esPolicyStatements = [] ]

    [#local storageProfile = getStorage(occurrence, ES_COMPONENT_TYPE)]
    [#local volume = (storageProfile.Volumes["data"])!{}]

    [#if ! volume.Size?? ]
        [@fatal
            message="ES Storage Profile doesn't have size for data Volume"
            detail="Update the storage profile to include a size for the ElasticSearch Data Volume"
            context={
                "Component" : occurrence.Core.FullName,
                "StorageProfile": solution.Profiles.Storage,
                "StorageConfiguration" : storageProfile
            }
        /]
    [/#if]

    [#local esCIDRs = getGroupCIDRs(solution.IPAddressGroups, true, occurrence) ]

    [#if !esCIDRs?has_content && !(esAuthentication == "SIG4ORIP") ]
        [@fatal
            message="No IP Policy Found"
            context=component
            detail="You must provide an IPAddressGroups list, for access from anywhere use the global IP Address Group"
        /]
    [/#if]

    [#if esCIDRs?seq_contains("0.0.0.0/0") && esAuthentication == "SIG4ORIP" ]
        [@fatal
            message="Invalid Authentication Config"
            context=component
            detail="Using a global IP Address with SIG4ORIP will remove SIG4 Auth. If this is intented change to IP authentication"
        /]
    [/#if]

    [#local esAdvancedOptions = {} ]
    [#list solution.AdvancedOptions as id,option]
        [#local esAdvancedOptions +=
            {
                option.Id : option.Value
            }
        ]
    [/#list]

    [#local AccessPolicyStatements = [] ]

    [#if esAuthentication == "SIG4ANDIP" ]

        [#local AccessPolicyStatements += [
                getPolicyStatement(
                    "es:ESHttp*",
                    "*",
                    {
                        "AWS" : "*"
                    },
                    {
                        "Null" : {
                            "aws:principaltype" : true
                        }
                    },
                    false
                )
            ]
        ]
    [/#if]

    [#if vpcAccess ]
        [#-- VPC Level Access Policies can not include IP's - Security Group manages IP control--]
        [#if esAuthentication == "IP" || esAuthentication == "SIG4ORIP" ]
            [#local AccessPolicyStatements +=
                [
                    getPolicyStatement(
                        "es:ESHttp*",
                        "*",
                        {
                            "AWS": "*"
                        }
                    )
                ]
            ]
        [/#if]
    [#else]
        [#-- Public ES Index Access Control --]
        [#if ( esAuthentication == "SIG4ANDIP" || esAuthentication == "IP" ) && !esCIDRs?seq_contains("0.0.0.0/0") ]

            [#local AccessPolicyStatements +=
                [
                    getPolicyStatement(
                        "es:ESHttp*",
                        "*",
                        {
                            "AWS" : "*"
                        },
                        {
                            "NotIpAddress" : {
                                "aws:SourceIp": esCIDRs
                            }
                        },
                        false
                    )
                ]
                ]
        [/#if]

        [#if esAuthentication == "SIG4ORIP" && esCIDRs?has_content ]
            [#local AccessPolicyStatements +=
                [
                    getPolicyStatement(
                        "es:ESHttp*",
                        "*",
                        {
                            "AWS": "*"
                        },
                        attributeIfContent(
                            "IpAddress",
                            esCIDRs,
                            {
                                "aws:SourceIp": esCIDRs
                            })
                    )
                ]
            ]
        [/#if]

        [#if esAuthentication == "IP" ]
            [#local AccessPolicyStatements +=
                [
                    getPolicyStatement(
                        "es:ESHttp*",
                        "*",
                        {
                            "AWS": "*"
                        },
                        attributeIfContent(
                            "IpAddress",
                            esCIDRs,
                            {
                                "aws:SourceIp": esCIDRs
                            })
                    )
                ]
            ]

        [/#if]
    [/#if]

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

            [#if deploymentSubsetRequired(ES_COMPONENT_TYPE, true)
                        && vpcAccess]
                [@createSecurityGroupRulesFromLink
                    occurrence=occurrence
                    groupId=sgId
                    linkTarget=linkTarget
                    inboundPorts=[ ports ]
                    networkProfile=networkProfile
                /]
            [/#if]

            [#switch linkTargetCore.Type]

                [#case USERPOOL_COMPONENT_TYPE]
                    [#local cognitoIntegration = true ]

                    [#local cognitoConfig +=
                        {
                            "UserPoolId" : linkTargetAttributes["USER_POOL"]
                        }]
                    [#break]
                [#case FEDERATEDROLE_COMPONENT_TYPE ]
                    [#local cognitoIntegration = true ]
                    [#local cognitoConfig +=
                        {
                            "IdentityPoolId" : getExistingReference(linkTargetResources["identitypool"].Id)
                        }]
                    [#break]

                [#case DATASET_COMPONENT_TYPE]
                    [#if linkTargetConfiguration.Solution.Engine == "s3" ]
                        [#local registryS3Source = linkTargetAttributes["DATASET_LOCATION"]]
                        [#local snapshotS3Destination = formatRelativePath(
                                                            "s3://",
                                                            getExistingReference(baselineComponentIds["AppData"]),
                                                            getAppDataFilePrefix(occurrence) )]

                        [#if deploymentSubsetRequired("epilogue", false)]
                            [@addToDefaultBashScriptOutput
                                content=[
                                    "info \"Syncing snapshot repository....\"",
                                    "aws --region \""
                                        + getRegion() + "\" s3 sync --delete --only-show-errors "
                                        + registryS3Source + " " + snapshotS3Destination
                                ]
                            /]
                        [/#if]
                    [/#if]
                    [#break]
            [/#switch]
        [/#if]
    [/#list]

    [#if cognitoIntegration ]
        [#if deploymentSubsetRequired("iam", true) && isPartOfCurrentDeploymentUnit(esServiceRoleId)]
            [@createRole
                    id=esServiceRoleId
                    trustedServices=["es.amazonaws.com"]
                    managedArns=["arn:aws:iam::aws:policy/AmazonESCognitoAccess"]
                    tags=getOccurrenceTags(occurrence)
                /]
        [/#if]

        [#if (cognitoConfig["IdentityPoolId"]!"")?has_content && (cognitoConfig["UserPoolId"]!"")?has_content ]
            [#local cognitoConfig +=
                {
                    "Enabled" : true
                }
            ]
        [#else]
            [#if deploymentSubsetRequired("es", false)]
                [@fatal
                    message="Incomplete Cognito integration"
                    context=component
                    detail="You must provide a link to both a federated role and a userpool to enabled authentication"
                /]
            [/#if]
        [/#if]

    [/#if]

    [#if solution.Logging ]
        [@setupLogGroup
            occurrence=occurrence
            logGroupId=lgId
            logGroupName=lgName
            loggingProfile=loggingProfile
            kmsKeyId=cmkKeyId
        /]
    [/#if]

    [#if deploymentSubsetRequired("iam", true && isPartOfCurrentDeploymentUnit(esSnapshotRoleId)) ]
        [@createRole
            id=esSnapshotRoleId
            trustedServices=["es.amazonaws.com"]
            policies=
                [
                    getPolicyDocument(
                        s3AllPermission(baselineComponentIds["AppData"], getAppDataFilePrefix(occurrence)),
                        "ESSnapshot"
                    )
                ]
            tags=getOccurrenceTags(occurrence)
        /]
    [/#if]

    [#-- In order to permit updates to the security policy, don't name the domain. --]
    [#-- Use tags in the console to find the right one --]
    [#-- "DomainName" : "${productName}-${segmentId}-${tierId}-${componentId}", --]
    [#if deploymentSubsetRequired("es", true)]

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

        [#if vpcAccess ]
            [@createSecurityGroup
                id=sgId
                name=sgName
                vpcId=vpcId
                tags=getOccurrenceTags(occurrence)
            /]

            [@createSecurityGroupRulesFromNetworkProfile
                occurrence=occurrence
                groupId=sgId
                networkProfile=networkProfile
                inboundPorts=ports
            /]

            [#local ingressNetworkRule = {
                    "Ports" : ports,
                    "IPAddressGroups" : solution.IPAddressGroups
            }]

            [@createSecurityGroupIngressFromNetworkRule
                occurrence=occurrence
                groupId=sgId
                networkRule=ingressNetworkRule
            /]
        [/#if]

        [@cfResource
            id=esId
            type="AWS::Elasticsearch::Domain"
            properties=
                {
                    "ElasticsearchVersion" : solution.Version,
                    "ElasticsearchClusterConfig" :
                        {
                            "InstanceType" : processorProfile.Processor,
                            "InstanceCount" : dataNodeCount
                        } +
                        valueIfTrue(
                            {
                                "DedicatedMasterEnabled" : true,
                                "DedicatedMasterCount" : master.Count,
                                "DedicatedMasterType" : (master.Processor)!"HamletFatal: No master processor type provided"
                            },
                            ( master.Count > 0 ),
                            {
                                "DedicatedMasterEnabled" : false
                            }
                        ) +
                        valueIfTrue(
                            {
                                "ZoneAwarenessEnabled" : true,
                                "ZoneAwarenessConfig" : {
                                    "AvailabilityZoneCount" : getZones()?size
                                }
                            },
                            (( !solution.VPCAccess && dataNodeCount > 1 ) || ( solution.VPCAccess && multiAZ )),
                            {
                                "ZoneAwarenessEnabled" : false
                            }
                        ),
                    "DomainEndpointOptions": {
                        "EnforceHTTPS": (securityProfile.ProtocolPolicy == "https-only"),
                        "TLSSecurityPolicy": securityProfile.HTTPSProfile
                    } +
                    attributeIfContent(
                        "CustomEndpoint",
                        esHostName
                    ) +
                    attributeIfContent(
                        "CustomEndpointEnabled",
                        esHostName,
                        true
                    ) +
                    attributeIfContent(
                        "CustomEndpointCertificateArn",
                        certificate,
                        getArn((certificate.Id)!"")
                    )
                } +
                attributeIfContent("AdvancedOptions", esAdvancedOptions) +
                attributeIfContent("SnapshotOptions", solution.Snapshot.Hour, solution.Snapshot.Hour) +
                attributeIfTrue(
                    "NodeToNodeEncryptionOptions",
                    (securityProfile.NodeTransitEncryption)!false,
                    {"Enabled": securityProfile.NodeTransitEncryption}
                ) +
                attributeIfContent(
                    "EBSOptions",
                    volume,
                    {
                        "EBSEnabled" : true,
                        "VolumeSize" : ((volume.Size)!"0")?number,
                        "VolumeType" : volume.Type
                    } +
                    attributeIfTrue(
                        "Iops",
                        volume.Type == "io1",
                        volume.Iops!"HamletFatal: Iops not defined for provisioned iops storage")
                ) +
                attributeIfTrue(
                    "EncryptionAtRestOptions",
                    solution.Encrypted,
                    {
                        "Enabled" : true,
                        "KmsKeyId" : getReference(cmkKeyId, ARN_ATTRIBUTE_TYPE)
                    }
                ) +
                attributeIfContent(
                    "AccessPolicies",
                    AccessPolicyStatements,
                    getPolicyDocumentContent(AccessPolicyStatements)
                ) +
                attributeIfTrue(
                    "CognitoOptions",
                    cognitoIntegration,
                    cognitoConfig
                ) +
                attributeIfTrue(
                    "LogPublishingOptions",
                    solution.Logging,
                    {
                        "ES_APPLICATION_LOGS" : {
                            "Enabled" : true,
                            "CloudWatchLogsLogGroupArn" : getReference(lgId, ARN_ATTRIBUTE_TYPE)
                        }
                    }
                ) +
                attributeIfTrue(
                    "VPCOptions",
                    vpcAccess,
                    networkConfiguration
                )
            tags=getOccurrenceTags(occurrence)
            outputs=ES_OUTPUT_MAPPINGS
            updatePolicy={
                "EnableVersionUpgrade" : solution.AllowMajorVersionUpdates
            }
        /]
    [/#if]
[/#macro]
