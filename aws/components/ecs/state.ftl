[#ftl]

[#function formatEcsClusterArn ecsId account={ "Ref" : "AWS::AccountId" }]
    [#return
        formatRegionalArn(
            "ecs",
            formatRelativePath(
                "cluster",
                getReference(ecsId)
            )
        )
    ]
[/#function]

[#-- Container --]
[#function formatContainerSecurityGroupIngressId resourceId container portRange source=""]
    [#return formatDependentSecurityGroupIngressId(
                resourceId,
                getContainerId(container),
                portRange,
                source)]
[/#function]

[#macro aws_ecs_cf_state occurrence parent={} ]
    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]

    [#local clusterId = formatResourceId(AWS_ECS_RESOURCE_TYPE, core.Id)]
    [#local clusterName = core.FullName ]

    [#local lgId = formatLogGroupId(core.Id) ]
    [#local lgName = core.FullAbsolutePath ]

    [#local computeProviderProfile  = getComputeProviderProfile(occurrence)]

    [#local asgEnabled = computeProviderProfile.Containers.Providers?seq_contains("_autoscalegroup")]

    [#-- migrate from Component based Ids over to Occurrence Ids--]
    [#local autoScaleGroupId = getExistingReference(
        formatResourceId(AWS_EC2_AUTO_SCALE_GROUP_RESOURCE_TYPE, getTierId(core.Tier), getComponentId(core.Component)),
        "",
        "",
        getOccurrenceDeploymentUnit(occurrence)
    )?has_content?then(
        formatResourceId(AWS_EC2_AUTO_SCALE_GROUP_RESOURCE_TYPE, getTierId(core.Tier), getComponentId(core.Component)),
        formatResourceId(AWS_EC2_AUTO_SCALE_GROUP_RESOURCE_TYPE, core.Id)
    )]

    [#-- migrate from Component based Ids over to Occurrence Ids--]
    [#local launchConfigId = getExistingReference(
        formatResourceId(AWS_EC2_LAUNCH_CONFIG_RESOURCE_TYPE, getTierId(core.Tier), getComponentId(core.Component)),
        "",
        "",
        getOccurrenceDeploymentUnit(occurrence)
    )?has_content?then(
        formatResourceId(AWS_EC2_LAUNCH_CONFIG_RESOURCE_TYPE, getTierId(core.Tier), getComponentId(core.Component)),
        formatResourceId(AWS_EC2_LAUNCH_CONFIG_RESOURCE_TYPE, core.Id)
    )]

    [#-- Always include the ASG so that we can still handle managed termination when disabling the asg --]
    [#local asgResources = {
        "autoScaleGroup" : {
            "Id" : autoScaleGroupId,
            "Name" : core.FullName,
            "Type" : AWS_EC2_AUTO_SCALE_GROUP_RESOURCE_TYPE,
            "Deployed": false
        }
    }]

    [#if asgEnabled ]

        [#local lgInstanceLogId = formatLogGroupId(core.Id, "instancelog") ]
        [#local lgInstanceLogName = formatAbsolutePath( core.FullAbsolutePath, "instancelog") ]

        [#local sgGroupId = getExistingReference(
                formatResourceId(AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE, getTierId(core.Tier), getComponentId(core.Component)),
                "",
                "",
                getOccurrenceDeploymentUnit(occurrence)
            )?has_content?then(
                formatResourceId(AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE, getTierId(core.Tier), getComponentId(core.Component)),
                formatResourceId(AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE, core.Id)
            )]

        [#local asgResources += {
            "securityGroup" : {
                "Id" : sgGroupId,
                "Name" : formatComponentFullName(core.Tier, core.Component ),
                "Type" : AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE
            },
            "role" : {
                "Id" : formatResourceId(AWS_IAM_ROLE_RESOURCE_TYPE, occurrence.Core.Id),
                "Type" : AWS_IAM_ROLE_RESOURCE_TYPE,
                "IncludeInDeploymentState" : false
            },
            "instanceProfile" : {
                "Id" : formatResourceId(AWS_EC2_INSTANCE_PROFILE_RESOURCE_TYPE, occurrence.Core.Id),
                "Type" : AWS_EC2_INSTANCE_PROFILE_RESOURCE_TYPE
            },
            "autoScaleGroup" : {
                "Id" : autoScaleGroupId,
                "Name" : core.FullName,
                "Type" : AWS_EC2_AUTO_SCALE_GROUP_RESOURCE_TYPE,
                "ComputeTasks" : [
                    COMPUTE_TASK_RUN_STARTUP_CONFIG,
                    COMPUTE_TASK_AWS_CFN_SIGNAL,
                    COMPUTE_TASK_AWS_ASG_STARTUP_SIGNAL,
                    COMPUTE_TASK_SYSTEM_VOLUME_MOUNTING,
                    COMPUTE_TASK_FILE_DIR_CREATION,
                    COMPUTE_TASK_HAMLET_ENVIRONMENT_VARIABLES,
                    COMPUTE_TASK_OS_SECURITY_PATCHING,
                    COMPUTE_TASK_ANTIVIRUS_CONFIG,
                    COMPUTE_TASK_AWS_CLI,
                    COMPUTE_TASK_SYSTEM_LOG_FORWARDING,
                    COMPUTE_TASK_AWS_ECS_AGENT_SETUP,
                    COMPUTE_TASK_USER_ACCESS,
                    COMPUTE_TASK_EFS_MOUNT
                ]
            },
            "launchConfig" : {
                "Id" : solution.AutoScaling.AlwaysReplaceOnUpdate?then(
                        formatId(launchConfigId, getCLORunId()),
                        launchConfigId
                ),
                "Type" : AWS_EC2_LAUNCH_CONFIG_RESOURCE_TYPE
            },
            "lgInstanceLog" : {
                "Id" : lgInstanceLogId,
                "Name" : lgInstanceLogName,
                "Type" : AWS_CLOUDWATCH_LOG_GROUP_RESOURCE_TYPE,
                "IncludeInDeploymentState" : false
            },
            "ecsASGCapacityProvider" : {
                "Id" : formatResourceId(AWS_ECS_CAPACITY_PROVIDER_RESOURCE_TYPE, core.Id, "asg" ),
                "Type" : AWS_ECS_CAPACITY_PROVIDER_RESOURCE_TYPE
            }
        }]
    [/#if]

    [#local logMetrics = {} ]
    [#list solution.LogMetrics as name,logMetric ]
        [#local logMetrics += {
            "lgMetric" + name : {
                "Id" : formatDependentLogMetricId( lgId, logMetric.Id ),
                "Name" : getCWMetricName( logMetric.Name, AWS_CLOUDWATCH_LOG_METRIC_RESOURCE_TYPE, core.ShortFullName ),
                "Type" : AWS_CLOUDWATCH_LOG_METRIC_RESOURCE_TYPE,
                "LogGroupName" : lgName,
                "LogGroupId" : lgId,
                "LogFilter" : logMetric.LogFilter
            }
        } +
        asgEnabled?then(
            {
                "lgMetric" + name + "instancelog": {
                    "Id" : formatDependentLogMetricId( lgInstanceLogId, logMetric.Id ),
                    "Name" : formatName(getCWMetricName( logMetric.Name, AWS_CLOUDWATCH_LOG_METRIC_RESOURCE_TYPE, core.ShortFullName ),  "instancelog"),
                    "Type" : AWS_CLOUDWATCH_LOG_METRIC_RESOURCE_TYPE,
                    "LogGroupName" : lgInstanceLogName,
                    "LogGroupId" : lgInstanceLogId,
                    "LogFilter" : logMetric.LogFilter
                }
            },
            {}
        )]
    [/#list]

    [#local autoScaling = {}]

    [#if asgEnabled ]
        [#if solution.HostScalingPolicies?has_content ]
            [#list solution.HostScalingPolicies as name, scalingPolicy ]

                [#if scalingPolicy.Type == "scheduled" ]
                    [#local autoScaling +=
                        {
                            "scalingPolicy" + name : {
                                "Id" : formatDependentAutoScalingEc2ScheduleId(autoScaleGroupId, name),
                                "Name" : formatName(core.FullName, name),
                                "Type" : AWS_AUTOSCALING_EC2_SCHEDULE_RESOURCE_TYPE
                            }
                        }
                    ]
                [#else]
                    [#local autoScaling +=
                        {
                            "scalingPolicy" + name : {
                                "Id" : formatDependentAutoScalingEc2PolicyId(autoScaleGroupId, name),
                                "Name" : formatName(core.FullName, name),
                                "Type" : AWS_AUTOSCALING_EC2_POLICY_RESOURCE_TYPE
                            }
                        }
                    ]
                [/#if]
            [/#list]
        [/#if]
    [/#if]

    [#local eipResources = {} ]

    [#local fixedIP = solution.FixedIP ]
    [#if asgEnabled && fixedIP]
        [#local processorProfile = getProcessor(occurrence, ECS_COMPONENT_TYPE)]
        [#if processorProfile.MaxCount?has_content]
            [#local maxSize = processorProfile.MaxCount ]
        [#else]
            [#local maxSize = processorProfile.MaxPerZone]
            [#if solution.MultiAZ]
                [#local maxSize = maxSize * getZones()?size]
            [/#if]
        [/#if]

        [#if fixedIP]
            [#list 1..maxSize as index]
                [#local eipResources +=
                    {
                        index : {
                            "eip" : {
                                "Id" : formatResourceId(AWS_EIP_RESOURCE_TYPE, core.Id, index),
                                "Type" : AWS_EIP_RESOURCE_TYPE
                            }
                        }
                    }
                ]
            [/#list]
        [/#if]
    [/#if]

    [#-- TODO(mfl): Use formatDependentRoleId() for roles --]
    [#assign componentState =
        {
            "Resources" : {
                "cluster" : {
                    "Id" : clusterId,
                    "Name" : clusterName,
                    "Type" : AWS_ECS_RESOURCE_TYPE,
                    "Monitored" : true
                },
                "lg" : {
                    "Id" : lgId,
                    "Name" : lgName,
                    "Type" : AWS_CLOUDWATCH_LOG_GROUP_RESOURCE_TYPE,
                    "IncludeInDeploymentState" : false
                },
                "ecsCapacityProviderAssociation" : {
                    "Id" : formatResourceId(AWS_ECS_CAPACITY_PROVIDER_ASSOCIATION_RESOURCE_TYPE, core.Id),
                    "Type" : AWS_ECS_CAPACITY_PROVIDER_ASSOCIATION_RESOURCE_TYPE
                }
            } +
            attributeIfContent("logMetrics", logMetrics) +
            attributeIfContent("eips", eipResources) +
            autoScaling +
            asgResources,
            "Attributes" : {
                "ARN" : getExistingReference(clusterId, ARN_ATTRIBUTE_TYPE)
            },
            "Roles" : {
                "Inbound" : {} +
                    asgEnabled?then(
                        {
                            "networkacl" : {
                                "SecurityGroups" : sgGroupId,
                                "Description" : core.FullName
                            }
                        },
                        {}
                    ),
                "Outbound" : {} +
                    asgEnabled?then(
                        {
                            "networkacl" : {
                                "Ports" : solution.ComputeInstance.ManagementPorts,
                                "SecurityGroups" : sgGroupId,
                                "Description" : core.FullName
                            }
                        },
                        {}
                    )
            }
        }
    ]
[/#macro]

[#macro aws_service_cf_state occurrence parent={} ]
    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]

    [#local parentResources = parent.State.Resources ]

    [#local networkMode = solution.NetworkMode]
    [#if solution.NetworkMode == "aws:awsvpc"]
        [#local networkMode = "awsvpc"]
    [/#if]

    [#if networkMode== "awsvpc" ]
        [#local securityGroupId = formatResourceId( AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE, core.Id ) ]
    [#else]
        [#local securityGroupId = parentResources["securityGroup"].Id ]
    [/#if]

    [#local serviceId = formatResourceId(AWS_ECS_SERVICE_RESOURCE_TYPE, core.Id)]
    [#local taskId = formatResourceId(AWS_ECS_TASK_RESOURCE_TYPE, core.Id) ]
    [#local taskName = core.Name]

    [#local parentResources = parent.State.Resources ]
    [#local ecsId = parentResources["cluster"].Id ]

    [#local lgId = formatDependentLogGroupId(taskId) ]
    [#local lgName = core.FullAbsolutePath ]

    [#local region = getExistingReference(serviceId, REGION_ATTRIBUTE_TYPE )!getRegion() ]

    [#local availablePorts = []]

    [#local images = {}]
    [#local occurrenceImage = constructAWSImageResource(
        occurrence,
        "docker",
        getCompositeObject(
            getAttributeSet(IMAGE_CONTAINER_ATTRIBUTESET_TYPE).Attributes,
            {}
        ),
        "default"
    )]

    [#if (occurrenceImage.default.Reference)?has_content ]
        [#local images = occurrenceImage]
    [/#if]

    [#list solution.Containers as id,container ]
        [#list container.Ports as id,port ]
            [#local availablePorts += [ port.Name ]]
        [/#list]

        [#-- if we can get a bulid reference setting then we aren't doing per container images --]
        [#if ( container.Image.Source == "registry" && getOccurrenceBuildReference(occurrence, true)?has_content ) ]
            [#continue]
        [/#if]
        [#local images = mergeObjects(images, constructAWSImageResource(occurrence, "docker", container.Image, id))]
    [/#list]

    [#local logMetrics = {} ]
    [#list solution.LogMetrics as name,logMetric ]
        [#local logMetrics += {
            "lgMetric" + name : {
                "Id" : formatDependentLogMetricId( lgId, logMetric.Id ),
                "Name" : getCWMetricName( logMetric.Name, AWS_CLOUDWATCH_LOG_METRIC_RESOURCE_TYPE, core.ShortFullName ),
                "Type" : AWS_CLOUDWATCH_LOG_METRIC_RESOURCE_TYPE,
                "LogGroupName" : lgName,
                "LogGroupId" : lgId,
                "LogFilter" : logMetric.LogFilter
            }
        }]
    [/#list]

    [#local autoScaling = {}]
    [#if solution.ScalingPolicies?has_content ]
        [#local autoScaling +=
            {
                "scalingTarget" : {
                    "Id" : formatResourceId(AWS_AUTOSCALING_APP_TARGET_RESOURCE_TYPE, core.Id),
                    "Type" : AWS_AUTOSCALING_APP_TARGET_RESOURCE_TYPE
                }
            }
        ]
        [#list solution.ScalingPolicies as name, scalingPolicy ]
            [#local autoScaling +=
                {
                    "scalingPolicy" + name : {
                        "Id" : formatDependentAutoScalingAppPolicyId(serviceId, name),
                        "Name" : formatName(core.FullName, name),
                        "Type" : AWS_AUTOSCALING_APP_POLICY_RESOURCE_TYPE
                    }
                }
            ]
        [/#list]
    [/#if]

    [#assign componentState =
        {
            "Resources" : {
                "service" : {
                    "Id" : serviceId,
                    "Type" : AWS_ECS_SERVICE_RESOURCE_TYPE,
                    "Monitored" : true
                },
                "task" : {
                    "Id" : taskId,
                    "Name" : taskName,
                    "Type" : AWS_ECS_TASK_RESOURCE_TYPE
                },
                "executionRole" : {
                    "Id" : formatDependentRoleId(taskId, "execution"),
                    "Type" : AWS_IAM_ROLE_RESOURCE_TYPE,
                    "IncludeInDeploymentState" : false
                }
            } +
            solution.TaskLogGroup?then(
                {
                    "lg" : {
                        "Id" : lgId,
                        "Name" : lgName,
                        "Type" : AWS_CLOUDWATCH_LOG_GROUP_RESOURCE_TYPE
                    }
                } +
                attributeIfContent("logMetrics", logMetrics),
                {}
            ) +
            attributeIfTrue(
                "taskrole"
                solution.UseTaskRole,
                {
                    "Id" : formatDependentRoleId(taskId),
                    "Type" : AWS_IAM_ROLE_RESOURCE_TYPE,
                    "IncludeInDeploymentState" : false
                }
            ) +
            attributeIfTrue(
                "securityGroup",
                networkMode == "awsvpc",
                {
                    "Id" : securityGroupId,
                    "Name" : core.FullName,
                    "Ports" : availablePorts,
                    "Type" : AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE
                }) +
            autoScaling,
            "Images": images,
            "Attributes" : {
                "CLUSTER_ARN" : getArn(ecsId),
                "ARN": getArn(serviceId)
            },
            "Roles" : {
                "Inbound" : {
                    "logwatch" : {
                        "Principal" : "logs." + region + ".amazonaws.com",
                        "LogGroupIds" : [ lgId ]
                    },
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

[#macro aws_task_cf_state occurrence parent={} ]
    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]

    [#local parentResources = parent.State.Resources ]
    [#local ecsId = parentResources["cluster"].Id ]

    [#local computeProviderProfile  = getComputeProviderProfile(parent)]
    [#local computeProviders = computeProviderProfile.Containers.Providers]

    [#local taskId = formatResourceId(AWS_ECS_TASK_RESOURCE_TYPE, core.Id) ]
    [#local taskName = core.Name]
    [#local taskRoleId = formatDependentRoleId(taskId)]

    [#local executionRoleId = formatDependentRoleId(taskId, "execution")]

    [#local occurrenceNetwork = getOccurrenceNetwork(parent) ]
    [#local networkLink = occurrenceNetwork.Link!{} ]

    [#local networkLinkTarget = getLinkTarget(parent, networkLink ) ]
    [#if ! networkLinkTarget?has_content ]
        [#return]
    [/#if]

    [#local networkConfiguration = networkLinkTarget.Configuration.Solution]
    [#local networkResources = networkLinkTarget.State.Resources ]

    [#local routeTableLinkTarget = getLinkTarget(occurrence, networkLink + { "RouteTable" : occurrenceNetwork.RouteTable }, false)]
    [#local routeTableConfiguration = routeTableLinkTarget.Configuration.Solution ]
    [#local publicRouteTable = routeTableConfiguration.Public ]

    [#local subnet = (getSubnets(core.Tier, networkResources))[0]]

    [#local networkMode = solution.NetworkMode]
    [#if solution.NetworkMode == "aws:awsvpc"]
        [#local networkMode = "awsvpc"]
    [/#if]

    [#if networkMode == "awsvpc" ]
        [#local securityGroupId = formatResourceId( AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE, core.Id ) ]
    [#else]
        [#local securityGroupId = parentResources["securityGroup"].Id ]
    [/#if]

    [#local availablePorts = []]
    [#local images = {}]
    [#local occurrenceImage = constructAWSImageResource(
        occurrence,
        "docker",
        getCompositeObject(
            getAttributeSet(IMAGE_CONTAINER_ATTRIBUTESET_TYPE).Attributes,
            {}
        ),
        "default"
    )]

    [#if (occurrenceImage.default.Reference)?has_content ]
        [#local images = occurrenceImage]
    [/#if]

    [#list solution.Containers as id,container ]
        [#list container.Ports as id,port ]
            [#local availablePorts += [ port.Name ]]
        [/#list]

        [#-- if we can get a bulid reference setting then we aren't doing per container images --]
        [#if ( container.Image.Source == "registry" && getOccurrenceBuildReference(occurrence, true)?has_content ) ]
            [#continue]
        [/#if]
        [#local images = mergeObjects(images, constructAWSImageResource(occurrence, "docker", container.Image, id))]
    [/#list]

    [#local lgId = formatDependentLogGroupId(taskId) ]
    [#local lgName = core.FullAbsolutePath ]

    [#local region = getExistingReference(taskId, REGION_ATTRIBUTE_TYPE )]

    [#local logMetrics = {} ]
    [#list solution.LogMetrics as name,logMetric ]
        [#local logMetrics += {
            "lgMetric" + name : {
                "Id" : formatDependentLogMetricId( lgId, logMetric.Id ),
                "Name" : getCWMetricName( logMetric.Name, AWS_CLOUDWATCH_LOG_METRIC_RESOURCE_TYPE, core.ShortFullName ),
                "Type" : AWS_CLOUDWATCH_LOG_METRIC_RESOURCE_TYPE,
                "LogGroupName" : lgName,
                "LogGroupId" : lgId,
                "LogFilter" : logMetric.LogFilter
            }
        }]
    [/#list]

    [#local schedules = {}]
    [#if solution.Schedules?has_content ]
        [#list solution.Schedules?values as schedule ]
            [#local schedules = mergeObjects(schedules, {
                    schedule.Id : {
                        "schedule" : {
                            "Id" : formatEventRuleId(occurrence, "schedule", schedule.Id),
                            "Type" : AWS_EVENT_RULE_RESOURCE_TYPE,
                            "IncludeInDeploymentState" : false
                        }
                    }
            })]
        [/#list]
    [/#if]

    [#local capacityProvider = getECSCapacityProviderStrategy(
        core.RawId,
        solution.Engine,
        mergeObjects({"Default" : {"Weight" : 1, "RequiredCount" : 1}, "Additional" : {}}, solution.Placement.ComputeProvider),
        (parentResources["ecsASGCapacityProvider"].Id)!"",
        computeProviders

    )[0].CapacityProvider ]

    [#assign componentState =
        {
            "Resources" : {
                "task" : {
                    "Id" : taskId,
                    "Name" : taskName,
                    "Type" : AWS_ECS_TASK_RESOURCE_TYPE
                },
                "executionRole" : {
                    "Id" : executionRoleId,
                    "Type" : AWS_IAM_ROLE_RESOURCE_TYPE,
                    "IncludeInDeploymentState" : false
                },
                "schedules" : schedules
            } +
            solution.TaskLogGroup?then(
                {
                    "lg" : {
                        "Id" : lgId,
                        "Name" : lgName,
                        "Type" : AWS_CLOUDWATCH_LOG_GROUP_RESOURCE_TYPE
                    }
                } +
                attributeIfContent("logMetrics", logMetrics),
                {}
            ) +
            attributeIfTrue(
                "taskrole"
                solution.UseTaskRole,
                {
                    "Id" : taskRoleId,
                    "Type" : AWS_IAM_ROLE_RESOURCE_TYPE,
                    "IncludeInDeploymentState" : false
                }
            ) +
            attributeIfContent(
                "scheduleRole",
                solution.Schedules,
                {
                    "Id" : formatDependentRoleId(taskId, "schedule"),
                    "Type" : AWS_IAM_ROLE_RESOURCE_TYPE,
                    "IncludeInDeploymentState" : false
                }
            ) +
            attributeIfTrue(
                "securityGroup",
                networkMode == "awsvpc",
                {
                    "Id" : securityGroupId,
                    "Name" : core.FullName,
                    "Type" : AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE
                }
            ),
            "Images": images,
            "Attributes" : {
                "ECSHOST" : getExistingReference(ecsId),
                "CAPACITY_PROVIDER" : capacityProvider,
                "DEFINITION" : solution.FixedName?then(
                    taskName,
                    getArn(taskId)
                ),
                "SECURITY_GROUP" : (networkMode == "awsvpc")?then(
                    getExistingReference(securityGroupId),
                    ""
                ),
                "SUBNET" : (networkMode == "awsvpc")?then(
                    subnet,
                    ""
                ),
                "PUBLIC_IP" : (networkMode == "awsvpc")?then(
                    publicRouteTable?c,
                    ""
                ),
                "LOG_GROUP_NAME" : lgName
            },
            "Roles" : {
                "Inbound" : {
                    "logwatch" : {
                        "Principal" : "logs." + region + ".amazonaws.com",
                        "LogGroupIds" : [ lgId ]
                    },
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
                    },
                    "run" :
                        ecsTaskRunPermission(ecsId) +
                        solution.UseTaskRole?then(
                            iamPassRolePermission(
                                getReference(taskRoleId, ARN_ATTRIBUTE_TYPE)
                            ),
                            []
                        ) +
                        (solution.Engine == "fargate")?then(
                            iamPassRolePermission(
                                getReference(executionRoleId, ARN_ATTRIBUTE_TYPE)
                            ),
                            []
                        )
                }
            }
        }
    ]
[/#macro]
