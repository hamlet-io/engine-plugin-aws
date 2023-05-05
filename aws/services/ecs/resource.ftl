[#ftl]

[#assign ECS_SERVICE_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        NAME_ATTRIBUTE_TYPE : {
            "Attribute" : "Name"
        },
        REGION_ATTRIBUTE_TYPE: {
            "Value" : { "Ref" : "AWS::Region" }
        }
    }
]

[#assign ECS_TASK_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        REGION_ATTRIBUTE_TYPE: {
            "Value" : { "Ref" : "AWS::Region" }
        }
    }
]

[#assign ECS_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "Attribute" : "Arn"
        }
    }]

[#assign ECS_CAPACITY_PROVIDER_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[#assign ECS_CAPACITY_PROVIDER_ASSOCIATION_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[#assign ecsMappings =
    {
        AWS_ECS_RESOURCE_TYPE : ECS_OUTPUT_MAPPINGS,
        AWS_ECS_SERVICE_RESOURCE_TYPE : ECS_SERVICE_OUTPUT_MAPPINGS,
        AWS_ECS_TASK_RESOURCE_TYPE : ECS_TASK_OUTPUT_MAPPINGS,
        AWS_ECS_CAPACITY_PROVIDER_RESOURCE_TYPE : ECS_CAPACITY_PROVIDER_OUTPUT_MAPPINGS,
        AWS_ECS_CAPACITY_PROVIDER_ASSOCIATION_RESOURCE_TYPE : ECS_CAPACITY_PROVIDER_ASSOCIATION_OUTPUT_MAPPINGS
    }
]

[#list ecsMappings as type, mappings]
    [@addOutputMapping
        provider=AWS_PROVIDER
        resourceType=type
        mappings=mappings
    /]
[/#list]

[@addCWMetricAttributes
    resourceType=AWS_ECS_RESOURCE_TYPE
    namespace="AWS/ECS"
    dimensions={
        "ClusterName" : {
            "Output" : {
                "Attribute" : REFERENCE_ATTRIBUTE_TYPE
            }
        }
    }
/]

[@addCWMetricAttributes
    resourceType=AWS_ECS_SERVICE_RESOURCE_TYPE
    namespace="AWS/ECS"
    dimensions={
        "ClusterName" : {
            "OtherOutput" : {
                "Id" : "cluster",
                "Property" : ""
            }
        },
        "ServiceName" : {
            "Output" : {
                "Attribute" : NAME_ATTRIBUTE_TYPE
            }
        }
    }
/]

[#macro createECSCluster
            id
            name=""
            containerInsights=false
            tags={}
            dependencies=[] ]

        [@cfResource
            id=id
            type="AWS::ECS::Cluster"
            outputs=ECS_OUTPUT_MAPPINGS
            tags=tags
            dependencies=dependencies
            properties={
                "ClusterSettings": [
                    {
                        "Name": "containerInsights",
                        "Value": containerInsights?then("enabled", "disabled")
                    }
                ]
            } +
            attributeIfContent(
                "ClusterName",
                name
            )
        /]
[/#macro]

[#macro createECSTask id
    name
    containers
    engine
    executionRoleRequired
    executionRole=""
    cpu=0
    memory=0
    networkMode=""
    fixedName=false
    role=""
    dependencies=""
    tags={}]

    [#local definitions = [] ]
    [#local volumes = []]
    [#local volumeNames = [] ]

    [#local memoryTotal = 0]
    [#local cpuTotal = 0]

    [#local placementConstraints = []]

    [#list containers as container]
        [#local mountPoints = [] ]
        [#list (container.Volumes!{}) as name,volume]
            [#local mountPoints +=
                [
                    {
                        "ContainerPath" : volume.ContainerPath,
                        "SourceVolume" : name,
                        "ReadOnly" : volume.ReadOnly
                    }
                ]
            ]

            [#if ! volumeNames?seq_contains(name) ]
                [#local dockerVolumeConfiguration = {}]
                [#local efsVolumeConfiguration = {}]

                [#switch volume.Driver ]
                    [#case "efs" ]
                        [#local efsVolumeConfiguration +=
                            {
                                "FilesystemId" : volume.EFS.FileSystemId,
                                "TransitEncryption" : "ENABLED",
                                "AuthorizationConfig" : {
                                    "IAM" : "ENABLED"
                                } +
                                attributeIfContent(
                                    "AccessPointId",
                                    (volume.EFS.AccessPointId)!""
                                )
                            }
                        ]
                        [#break]
                    [#default]

                        [#local dockerVolumeConfiguration +=
                            volume.PersistVolume?then(
                                {
                                    "Scope" : "shared",
                                    "Autoprovision", volume.AutoProvision
                                },
                                {}
                            ) +
                            attributeIfContent(
                                "DriverOpts",
                                volume.DriverOpts!{}
                            ) +
                            attributeIfTrue(
                                "Driver",
                                (volume.Driver != "local"),
                                volume.Driver
                            ) +
                            attributeIfContent(
                                "Scope",
                                volume.Scope!""
                            )
                        ]
                [/#switch]


                [#local volumes +=
                    [
                        {
                            "Name" : name
                        } +
                        attributeIfContent(
                            "Host",
                            volume.HostPath,
                            {"SourcePath" : volume.HostPath!""}
                        ) +
                        attributeIfContent(
                            "DockerVolumeConfiguration",
                            dockerVolumeConfiguration
                        ) +
                        attributeIfContent(
                            "EFSVolumeConfiguration",
                            efsVolumeConfiguration
                        )
                    ]
                ]
            [/#if]
            [#local volumeNames += [ name ] ]
        [/#list]

        [#local portMappings = [] ]
        [#list (container.PortMappings![]) as portMapping]
            [#local portMappings +=
                [
                    {
                        "ContainerPort" : ports[portMapping.ContainerPort].Port,
                        "HostPort" : portMapping.DynamicHostPort?then(0, ports[portMapping.HostPort].Port)
                    } +
                    attributeIfTrue(
                        "Protocol",
                        (ports[portMapping.ContainerPort].IPProtocol == "udp"),
                        "udp"
                    )
                ]
            ]
        [/#list]

        [#local environment = [] ]
        [#list (container.Environment!{}) as name,value]
            [#local environment +=
                [
                    {
                        "Name" : name,
                        "Value" : value
                    }
                ]
            ]
        [/#list]

        [#local extraHosts = [] ]
        [#list (container.Hosts!{}) as name,value]
            [#local extraHosts +=
                [
                    {
                        "Hostname" : name,
                        "IpAddress" : value
                    }
                ]
            ]
        [/#list]

        [#local ulimits = []]
        [#list (container.Ulimits!{}) as id, limit ]
            [#local ulimits +=
                [
                    {
                        "Name" : limit.Name,
                        "HardLimit" : limit.HardLimit,
                        "SoftLimit" : limit.SoftLimit
                    }
                ]
            ]
        [/#list]

        [#local secrets = []]
        [#list (container.SecretEnv!{})?values as secret]
            [#local secrets +=
                [
                    {
                        "Name" : secret.EnvName,
                        "ValueFrom" : secret.SecretRef
                    }
                ]
            ]
        [/#list]

        [#local placementConstraints = combineEntities( placementConstraints, container.PlacementConstraints![], UNIQUE_COMBINE_BEHAVIOUR) ]

        [#if engine == "fargate" ]
            [#local memoryTotal += container.MaximumMemory]
            [#local cpuTotal += container.Cpu]
        [/#if]

        [#local linuxParameters = {}]
        [#if (container.RunCapabilities![])?has_content  ]
            [#local linuxParameters = mergeObjects(
                linuxParameters,
                {
                    "Capabilities" : {
                        "Add" : (container.RunCapabilities)![]
                    }
                }
            )]
        [/#if]

        [#if container.InitProcess ]
            [#local linuxParameters = mergeObjects(
                linuxParameters,
                {
                    "InitProcessEnabled" : container.InitProcess
                }
            )]
        [/#if]

        [#local definitions +=
            [
                {
                    "Name" : container.Name,
                    "Image": container.Image,
                    "Essential" : container.Essential,
                    "MemoryReservation" : container.MemoryReservation,
                    "LogConfiguration" :
                        {
                            "LogDriver" : container.LogDriver
                        } +
                        attributeIfContent("Options", container.LogOptions)
                } +
                attributeIfContent("Environment", environment) +
                attributeIfContent("Secrets", secrets) +
                attributeIfContent("MountPoints", mountPoints) +
                attributeIfContent("ExtraHosts", extraHosts) +
                attributeIfContent("Memory", container.MaximumMemory!"") +
                attributeIfContent("Cpu", container.Cpu!"") +
                attributeIfContent("ResourceRequirements", (container.Gpu)!"",
                                        [
                                            {
                                                "Type" : "GPU",
                                                "Value" : (container.Gpu)!""
                                            }
                                        ]) +
                attributeIfContent("PortMappings", portMappings) +
                attributeIfContent("LinuxParameters", linuxParameters ) +
                attributeIfTrue("Privileged", container.Privileged, container.Privileged!"") +
                attributeIfContent("WorkingDirectory", container.WorkingDirectory!"") +
                attributeIfContent("Links", container.ContainerNetworkLinks![] ) +
                attributeIfContent("EntryPoint", container.EntryPoint![]) +
                attributeIfContent("Command", container.Command![]) +
                attributeIfContent("HealthCheck", container.HealthCheck!{}) +
                attributeIfContent("Hostname", container.Hostname!"") +
                attributeIfContent("Ulimits", ulimits ) +
                attributeIfContent("DependsOn", container.DependsOn) +
                attributeIfTrue(
                    "ReadonlyRootFilesystem",
                    container.ReadonlyRootFilesystem,
                    container.ReadonlyRootFilesystem
                )
            ]
        ]
    [/#list]

    [#local placementConstraintProps = []]
    [#list placementConstraints as placementConstraint ]
        [#local placementConstraintProps +=
                [
                    {
                        "Type" : "memberOf",
                        "Expression" : placementConstraint
                    }
                ]]
    [/#list]


    [#-- Allow for explicit override of the cpu/memory limits for the task --]
    [#if cpu > 0 ]
        [#local cpuTotal = cpu]
    [/#if]

    [#if memory > 0]
        [#local memoryTotal = memory ]
    [/#if]

    [#local validFargateCPU = [ 256, 512, 1024, 2048, 4096, 8192, 16384 ] ]
    [#if engine == "fargate" && !(validFargateCPU?seq_contains(cpuTotal) )  ]
        [@fatal
            message="Invalid CPU allocation for fargate container - Ensure the total container allocation is in the valid range or set a shared allocation at the service/task level"
            context={
                "Task": {
                    "Id": id,
                    "Name": name
                },
                "TotalAllocation": cpuTotal,
                "ValidAllocation": validFargateCPU
            }
        /]
    [/#if]

    [#local taskProperties = {
        "ContainerDefinitions" : definitions
        } +
        attributeIfContent("Volumes", volumes)  +
        attributeIfContent("TaskRoleArn", role, getReference(role, ARN_ATTRIBUTE_TYPE)) +
        attributeIfContent("NetworkMode", networkMode) +
        attributeIfTrue("Family", fixedName, name ) +
        attributeIfTrue("ExecutionRoleArn", executionRoleRequired, getArn(executionRole)) +
        valueIfTrue(
            {
                "RequiresCompatibilities" : [ engine?upper_case ]
            },
            (engine == "fargate")
        ) +
        attributeIfContent("PlacementConstraints", placementConstraintProps) +
        attributeIfTrue(
            "Cpu",
            cpuTotal > 0,
            cpuTotal
        ) +
        attributeIfTrue(
            "Memory",
            memoryTotal > 0,
            memoryTotal
        )
    ]

    [@cfResource
        id=id
        type="AWS::ECS::TaskDefinition"
        properties=taskProperties
        dependencies=dependencies
        outputs=ECS_TASK_OUTPUT_MAPPINGS
        tags=tags
    /]
[/#macro]

[#macro createECSService id
            ecsId
            desiredCount
            taskId
            loadBalancers
            serviceRegistries
            engine
            circuitBreaker
            executeCommand
            capacityProviderStrategy={}
            platformVersion=""
            networkMode=""
            networkConfiguration={}
            placement={}
            dependencies=""
            tags={}
    ]

    [#-- define an array of constraints --]
    [#-- for potential support of "memberOf" type placement constraint --]
    [#local placementConstraints = [] ]
    [#if placement.DistinctInstance && (engine != "fargate")]
        [#local placementConstraints += [{
            "Type" : "distinctInstance"
        }]]
    [/#if]

    [#if placement.Strategy?seq_contains("daemon") && (placement.Strategy)?size > 1 ]
        [@fatal
            message="ECS daemon placement strategy can not be used with other strategies"
            detail={
                "ServiceId" : id,
                "Placment" : placement
            }
        /]
    [/#if]

    [#local daemonMode = false ]
    [#if placement.Strategy?seq_contains("daemon") ]
        [#local daemonMode = true ]
    [/#if]

    [#local placementStrategies = []]
    [#list placement.Strategy as strategy ]
        [#switch strategy?lower_case ]
            [#case "spread-multiaz" ]
                [#local placementStrategies += [
                    {
                        "Field" : "attribute:ecs.availability-zone",
                        "Type" : "spread"
                    }
                ]]
                [#break]
            [#case "spread-instance" ]
                [#local placementStrategies += [
                    {
                        "Field" : "instanceId",
                        "Type" : "spread"
                    }
                ]]
                [#break]
            [#case "binpack-cpu" ]
                [#local placementStrategies += [
                    {
                        "Field" : "cpu",
                        "Type" : "binpack"
                    }
                ]]
                [#break]
            [#case "binpack-memory" ]
                [#local placementStrategies += [
                    {
                        "Field" : "memory",
                        "Type" : "binpack"
                    }
                ]]
                [#break]
            [#case "random" ]
                [#local placementStrategies += [
                    {
                        "Type" : "random"
                    }
                ]]
                [#break]
        [/#switch]
    [/#list]

    [@cfResource
        id=id
        type="AWS::ECS::Service"
        properties=
            {
                "Cluster" : getExistingReference(ecsId),
                "TaskDefinition" : getReference(taskId),
                "PropagateTags": "SERVICE",
                "DeploymentConfiguration" :
                    (desiredCount > 1)?then(
                        {
                            "MaximumPercent" : 100,
                            "MinimumHealthyPercent" : 50
                        },
                        {
                            "MaximumPercent" : 100,
                            "MinimumHealthyPercent" : 0
                        }) +
                    circuitBreaker?then(
                        {
                            "DeploymentCircuitBreaker" : {
                                "Enable" : true,
                                "Rollback" : true
                            }
                        },
                        {}
                    )
            } +
            valueIfContent(
                {
                    "LoadBalancers" : loadBalancers
                },
                loadBalancers
            ) +
            valueIfContent(
                {
                    "ServiceRegistries" : serviceRegistries
                },
                serviceRegistries
            ) +
            valueIfTrue(
                {
                    "SchedulingStrategy" : "DAEMON"
                },
                (daemonMode && engine == "ec2" ),
                {
                    "DesiredCount" : desiredCount
                }
            ) +
            attributeIfTrue(
                "PlatformVersion",
                ( engine == "fargate" && platformVersion?upper_case != "LATEST" ),
                platformVersion?upper_case
            ) +
            attributeIfContent(
                "NetworkConfiguration",
                networkConfiguration
            ) +
            attributeIfTrue(
                "PlacementConstraints",
                (engine != "fargate") && (placementConstraints?size > 0),
                placementConstraints
            ) +
            attributeIfTrue(
                "PlacementStrategies",
                (engine != "fargate") && (placementStrategies?size > 0),
                placementStrategies
            ) +
            attributeIfTrue(
                "CapacityProviderStrategy",
                (capacityProviderStrategy?has_content && ! daemonMode)
                capacityProviderStrategy
            ) +
            attributeIfTrue(
                "LaunchType",
                ! (capacityProviderStrategy?has_content) || daemonMode,
                engine?upper_case
            ) +
            attributeIfTrue(
                "EnableExecuteCommand",
                executeCommand,
                executeCommand
            )
        dependencies=dependencies
        outputs=ECS_SERVICE_OUTPUT_MAPPINGS
        tags=tags
    /]
[/#macro]

[#macro createECSCapacityProvider
        id
        asgId
        managedScaling=true
        minStepSize=1
        maxStepSize=10000
        targetCapacity=90
        managedTermination=true
        tags={}
        dependencies=[] ]

    [@cfResource
        id=id
        type="AWS::ECS::CapacityProvider"
        outputs=ECS_CAPACITY_PROVIDER_OUTPUT_MAPPINGS
        tags=tags
        properties={
            "AutoScalingGroupProvider" : {
                "AutoScalingGroupArn" : getReference(asgId),
                "ManagedTerminationProtection" :
                        managedTermination?then(
                            "ENABLED",
                            "DISABLED"
                        ),
                "ManagedScaling" :
                    valueIfTrue(
                        {
                            "Status" : "ENABLED",
                            "MinimumScalingStepSize" : minStepSize,
                            "MaximumScalingStepSize" : maxStepSize,
                            "TargetCapacity" : targetCapacity
                        },
                        managedScaling,
                        {
                            "Status" : "DISABLED"
                        }
                    )
            }
        }
        dependencies=dependencies

    /]
[/#macro]

[#function getECSCapacityProviderStrategy rawId engine computeProviderPlacement ecsASGCapacityProviderId ]
    [#local capacityProviderStrategy = []]

    [#local baseCapacityProvider = computeProviderPlacement.Default ]
    [#local additionalCapacityProviders = (computeProviderPlacement.Additional)!{} ]

    [#switch engine ]
        [#case "ec2"]
            [#if baseCapacityProvider.Provider == "_engine" ]
                [#local capacityProviderStrategy += [
                    getECSCapacityProviderStrategyRule(
                        baseCapacityProvider + { "Provider" : "_autoscalegroup" },
                        ecsASGCapacityProviderId
                    )
                ]]
            [#else]
                [@fatal
                    message="ECS Service engine Ec2 only supports the _engine compute provider"
                    context={
                        "ServiceId" : rawId,
                        "Engine" : engine,
                        "DefaultComputeProvider" : baseCapacityProvider
                    }
                /]
            [/#if]

            [#if additionalCapacityProviders?has_content ]
                [@fatal
                    message="ECS Service engine Ec2 doesn't support additional compute providers"
                    context={
                        "ServiceId" : rawId,
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
                    getECSCapacityProviderStrategyRule(
                        baseCapacityProvider + { "Provider" : "aws:fargate" }
                    )
                ]]
            [#elseif baseCapacityProvider.Provider == "aws:fargate" || baseCapacityProvider.Provider == "aws:fargate_spot" ]
                [#local capacityProviderStrategy += [
                    getECSCapacityProviderStrategyRule(
                        baseCapacityProvider
                    )
                ]]
            [#else]
                [@fatal
                    message="ECS Service engine fargate only supports fargate based providers"
                    context={
                        "ServiceId" : rawId,
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
                        getECSCapacityProviderStrategyRule(
                            additionalProvider
                        )
                    ]]
                [#else]
                    [@fatal
                        message="ECS Service engine fargate only supports fargate based providers"
                        context={
                            "ServiceId" : rawId,
                            "Engine" : engine,
                            "AdditonalComputeProviders" : additionalCapacityProviders
                        }
                    /]
                [/#if]
            [/#list]
            [#break]
    [/#switch]

    [#return capacityProviderStrategy]
[/#function]


[#function getECSCapacityProviderStrategyRule computeProfileRule asgCapacityProviderId="" ]
    [#local provider = "" ]
    [#switch computeProfileRule.Provider ]
        [#case "_autoscalegroup" ]
            [#if asgCapacityProviderId?has_content ]
                [#local provider = getReference(asgCapacityProviderId)]
            [/#if]
            [#break]
        [#case "aws:fargate" ]
            [#local provider = "FARGATE" ]
            [#break]
        [#case "aws:fargatespot" ]
        [#case "aws:fargate_spot" ]
            [#local provider = "FARGATE_SPOT" ]
            [#break]

        [#default]
            [@fatal
                message="Unkown ECS Compute Capacity Provider"
                context=computeProfileRule
            /]
    [/#switch]

    [#return
        {
            "CapacityProvider" : provider,
            "Weight" : (computeProfileRule.Weight)?number?c
        } +
        attributeIfContent(
            "Base",
            computeProfileRule.RequiredCount!""
        )
    ]
[/#function]

[#macro createECSCapacityProviderAssociation
        id
        clusterId
        capacityProviders=[]
        defaultCapacityProviderStrategies=[]
        dependencies=[]]

        [@cfResource
            id=id
            type="AWS::ECS::ClusterCapacityProviderAssociations"
            outputs=ECS_CAPACITY_PROVIDER_ASSOCIATION_OUTPUT_MAPPINGS
            properties={
                "Cluster" : getReference(clusterId),
                "CapacityProviders" : capacityProviders,
                "DefaultCapacityProviderStrategy" : defaultCapacityProviderStrategies
            }
            dependencies=dependencies
        /]
[/#macro]

[#assign ECS_DEFAULT_MEMORY_LIMIT_MULTIPLIER=1.5 ]

[#function getECSTaskContainers ecs task]

    [#local core = task.Core ]
    [#local solution = task.Configuration.Solution ]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(task, [ "OpsData", "AppData", "Encryption" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]

    [#local operationsBucket = getExistingReference(baselineComponentIds["OpsData"]) ]
    [#local dataBucket = getExistingReference(baselineComponentIds["AppData"])]

    [#local tier = core.Tier ]
    [#local component = core.Component ]

    [#local containers = [] ]

    [#list solution.Containers as containerId, container]
        [#local containerPortMappings = [] ]
        [#local containerLinks = mergeObjects( solution.Links, container.Links) ]
        [#local inboundPorts = []]
        [#local ingressRules = []]
        [#local egressRules = []]

        [#local image = getOccurrenceImage(task, containerId) ]
        [#list container.Ports?values as port]

            [#local containerPortMapping =
                {
                    "ContainerPort" :
                        contentIfContent(
                            port.Container!"",
                            port.Name
                        ),
                    "HostPort" : port.Name,
                    "DynamicHostPort" : port.DynamicHostPort
                } ]

            [#if port.LB.Configured]
                [#local lbLink = getLBLink( task, port )]

                [#if isDuplicateLink(containerLinks, lbLink) ]
                    [@fatal
                        message="Duplicate Link Name"
                        context=containerLinks
                        detail=lbLink /]
                    [#continue]
                [/#if]

                [#-- Treat the LB link like any other - this will also detect --]
                [#-- if the target is missing                                 --]
                [#local containerLinks += lbLink]

                [#-- Ports should only be defined if connecting to a load balancer --]
                [#list lbLink as key,loadBalancer]
                    [#local containerPortMapping +=
                        {
                            "LoadBalancer" :
                                {
                                    "Link" : loadBalancer.Name
                                }
                        }
                    ]

                [/#list]

            [/#if]

            [#if port.Registry.Configured]
                [#local registryLink = getRegistryLink(task, port)]

                [#if isDuplicateLink(containerLinks, registryLink) ]
                    [@fatal
                        message="Duplicate Link Name"
                        context=containerLinks
                        detail=RegistryLink /]
                    [#continue]
                [/#if]

                [#-- Add to normal container links --]

                [#local containerLinks += registryLink]

                [#list registryLink as key,serviceRegistry]
                    [#local containerPortMapping +=
                        {
                            "ServiceRegistry" :
                                {
                                    "Link" : serviceRegistry.Name
                                }
                        }
                    ]

                [/#list]
            [/#if]

            [#if port.IPAddressGroups?has_content]
                [#if ["awsvpc", "aws:awsvpc" ]?seq_contains(solution.NetworkMode) ]
                    [#list getGroupCIDRs(port.IPAddressGroups, true, task ) as cidr]
                        [#local ingressRules += [ {
                            "port" : port.DynamicHostPort?then(0,contentIfContent(
                                                                            port.Container!"",
                                                                            port.Name )),
                            "cidr" : cidr
                        }]]
                    [/#list]
                [#else]
                    [@fatal
                        message="Port IP Address Groups not supported for port configuration"
                        context=container
                        detail=port /]
                    [#continue]
                [/#if]
            [/#if]

            [#local containerPortMappings += [containerPortMapping] ]
            [#local inboundPorts += [ port.Name ]]
        [/#list]

        [#local logDriver =
            valueIfTrue(
                "json-file",
                container.LocalLogging,
                container.LogDriver
            ) ]

        [#if logDriver != "awslogs" && solution.Engine == "fargate" ]
            [@fatal
                message="The fargate engine only supports the awslogs logging driver"
                context=solution
                /]
            [#break]
        [/#if]

        [#local containerLgId =
            formatDependentLogGroupId(core.Id,  container.Id?split("-")) ]
        [#local containerLgName =
            formatAbsolutePath(core.FullAbsolutePath, container.Name?split("-")) ]
        [#local containerLogGroup =
            valueIfTrue(
                {
                    "Id" : containerLgId,
                    "Name" : containerLgName
                },
                container.ContainerLogGroup
            ) ]

        [#local logGroupId =
            valueIfTrue(
                containerLgId,
                container.ContainerLogGroup,
                valueIfTrue(
                    task.State.Resources["lg"].Id!"",
                    solution.TaskLogGroup,
                    valueIfTrue(
                        ecs.State.Resources["lg"].Id!"",
                        ecs.Configuration.Solution.ClusterLogGroup,
                        "HamletFatal: Logs type is awslogs but no group defined"
                    )
                )
            ) ]

        [#local logOptions =
            logDriver?switch(
                "fluentd",
                {
                    "tag" : concatenate(
                                [
                                    "docker",
                                    productId,
                                    segmentId,
                                    tier.Id,
                                    component.Id,
                                    container.Id
                                ],
                                "."
                            )
                },
                "awslogs",
                {
                    "awslogs-group" : getReference(logGroupId),
                    "awslogs-region" : getRegion(),
                    "awslogs-stream-prefix" : core.Name
                },
                {}
            )]

        [#local contextLinks = getLinkTargets(task, containerLinks) ]

        [#local containerDetails = {
            "Id" : contentIfContent(
                    (container.Extensions[0])!"",
                    getContainerId(container)
            ),
            "Name" : getContainerName(container)
        }]

        [#-- Add in extension specifics including override of defaults --]
        [#-- Extensions are based on occurrences so we need to create a fake occurrence --]

        [#-- add an extra setting namespace which is used to find the container build refernces when images --]
        [#-- are manged by a container registry --]
        [#local containerSettingNamespaces = combineEntities(
            task.Configuration.SettingNamespaces,
            [
                {
                    "Key" : formatName(task.Core.RawName, containerId)?lower_case,
                    "Match" : "partial"
                }
            ],
            APPEND_COMBINE_BEHAVIOUR
        )]
        [#local containerBuildSettings = getAdditionalBuildSettings(containerSettingNamespaces)]

        [#local containerOccurrence = mergeObjects(
            task,
            {
                "Configuration" : {
                    "SettingNamespaces" : containerSettingNamespaces
                }
            }
        )]
        [#local containerOccurrence = mergeObjects(
            containerOccurrence,
            {
                "Configuration" : {
                    "Settings" : {
                        "Build" : containerBuildSettings
                    },
                    "Environment" : {
                        "Build" : getSettingsAsEnvironment(containerBuildSettings)
                    }
                }
            }
        )]

        [#local dependsOn = []]
        [#list container.DependsOn as k,v ]
            [#local dependsOn += [
                    {
                        "ContainerName" : (v.ContainerName)!k,
                        "Condition" : v.Condition
                    }
                ]
            ]
        [/#list]

        [#local containerOccurrence = mergeObjects(
            containerOccurrence,
            constructOccurrenceImageSettings(containerOccurrence)
        )]

        [#local _context =
            containerDetails +
            {
                "Essential" : container.Essential,
                "Image": image.ImageLocation,
                "MemoryReservation" : container.MemoryReservation,
                "Mode" : getContainerMode(container),
                "LogDriver" : logDriver,
                "LogOptions" : logOptions,
                "DefaultEnvironment" : defaultEnvironment(containerOccurrence, contextLinks, baselineLinks),
                "Environment" :
                    {
                        "APP_RUN_MODE" : getContainerMode(container),
                        "AWS_REGION" : getRegion(),
                        "AWS_DEFAULT_REGION" : getRegion()
                    },
                "Links" : contextLinks,
                "BaselineLinks" : baselineLinks,
                "DefaultCoreVariables" : true,
                "DefaultEnvironmentVariables" : true,
                "DefaultBaselineVariables" : true,
                "DefaultLinkVariables" : true,
                "Policy" : iamStandardPolicies(task, baselineComponentIds),
                "Privileged" : container.Privileged,
                "LogMetrics" : container.LogMetrics,
                "Alerts" : container.Alerts,
                "Container" : container,
                "InitProcess" : container.InitProcess,
                "DependsOn" : dependsOn,
                "ReadonlyRootFilesystem": container.ReadonlyRootFilesystem
            } +
            attributeIfContent("LogGroup", containerLogGroup) +
            attributeIfContent("Cpu", container.Cpu) +
            attributeIfContent("Gpu", container.Gpu) +
            attributeIfTrue(
                "MaximumMemory",
                container.MaximumMemory?has_content &&
                    container.MaximumMemory?is_number &&
                    container.MaximumMemory > 0,
                container.MaximumMemory!""
            ) +
            attributeIfTrue(
                "MaximumMemory",
                !container.MaximumMemory??,
                container.MemoryReservation*ECS_DEFAULT_MEMORY_LIMIT_MULTIPLIER
            ) +
            attributeIfContent("PortMappings", containerPortMappings) +
            attributeIfContent("IngressRules", ingressRules) +
            attributeIfContent("InboundPorts", inboundPorts) +
            attributeIfContent("RunCapabilities", container.RunCapabilities) +
            attributeIfContent("ContainerNetworkLinks", container.ContainerNetworkLinks) +
            attributeIfContent("PlacementConstraints", container.PlacementConstraints![] ) +
            attributeIfContent("Ulimits", container.Ulimits )
        ]

        [#local linkIngressRules = [] ]
        [#list _context.Links as linkId,linkTarget]
            [#local linkTargetCore = linkTarget.Core ]
            [#local linkTargetConfiguration = linkTarget.Configuration ]
            [#local linkTargetResources = linkTarget.State.Resources ]
            [#local linkTargetAttributes = linkTarget.State.Attributes ]
            [#local linkTargetRoles = linkTarget.State.Roles ]

            [#if (linkTargetRoles.Outbound["networkacl"]!{})?has_content ]
                [#local egressRules += [ linkTargetRoles.Outbound["networkacl"] ]]
            [/#if]

            [#if linkTarget.Direction?lower_case == "Inbound" && linkTarget.Role == "networkacl" ]
                [#local linkIngressRules += [  mergeObjects( linkTargetRoles.Inbound["networkacl"],  { "Ports" : inboundPorts } ) ] ]]
            [/#if]

            [#switch linkTargetCore.Type]
                [#case DATAVOLUME_COMPONENT_TYPE]

                    [#local dataVolumeEngine = linkTargetAttributes["ENGINE"] ]

                    [#if ! ( ecs.Configuration.Solution.VolumeDrivers?seq_contains(dataVolumeEngine)) ]
                            [@fatal
                                message="Volume driver for this data volume not configured for ECS Cluster"
                                context=ecs.Configuration.Solution.VolumeDrivers
                                detail=ecs /]
                    [/#if]

                    [#local _context +=
                        {
                            "DataVolumes" :
                                (_context.DataVolumes!{}) +
                                {
                                    linkId : {
                                        "Name" : linkTargetAttributes["VOLUME_NAME"],
                                        "Engine" : linkTargetAttributes["ENGINE"]
                                    }
                                }
                        }]
                    [#break]
                [#case FILESHARE_COMPONENT_TYPE]
                [#case FILESHARE_MOUNT_COMPONENT_TYPE]
                    [#local _context +=
                        {
                            "DataVolumes" :
                                (_context.DataVolumes!{}) +
                                {
                                    linkId : {
                                        "Name" : formatName("efs", linkTargetAttributes["EFS"], linkTargetAttributes["ACCESS_POINT_ID"]!""),
                                        "Engine" : "efs",
                                        "EFS" : {
                                            "FileSystemId" : linkTargetAttributes["EFS"]
                                        } +
                                        attributeIfContent(
                                            "AccessPointId",
                                            (linkTargetAttributes["ACCESS_POINT_ID"]!"")
                                        )
                                    }
                                }
                        }

                    ]
                    [#break]
                [#case SECRETSTORE_SECRET_COMPONENT_TYPE ]
                    [#local _context = mergeObjects(
                        _context,
                        {
                            "Secrets" : {
                                linkId : {
                                    "Provider" : linkTargetAttributes["ENGINE"],
                                    "Ref" : linkTargetResources["secret"].Id,
                                    "EncryptionKeyId" : linkTargetResources["secret"].cmkKeyId
                                }
                            }
                        })]
                    [#break]

                [#case DB_COMPONENT_TYPE]
                    [#if ((linkTargetAttributes["SECRET_ARN"])!"")?has_content ]
                        [#local _context = mergeObjects(
                            _context,
                            {
                                "Secrets" : {
                                    linkId : {
                                        "Provider" : linkTargetResources["rootCredentials"]["secret"].Provider,
                                        "Ref" : linkTargetResources["rootCredentials"]["secret"].Id,
                                        "EncryptionKeyId" : linkTargetResources["rootCredentials"]["secret"].cmkKeyId
                                    }
                                }
                            }
                        )]
                    [/#if]
                    [#break]
            [/#switch]
        [/#list]

        [#-- Add link based sec rules --]
        [#local _context += { "EgressRules" : egressRules }]
        [#local _context += { "LinkIngressRules" : linkIngressRules }]

        [#-- Add in extension specifics including override of defaults --]
        [#-- Extensions are based on occurrences so we need to create a fake occurrence --]
        [#local containerOccurrence = mergeObjects(
            containerOccurrence,
            {
                "Core" : {
                    "Component" : containerDetails
                },
                "Configuration" : {
                    "Solution" : container
                }
            }
        )]
        [#local _context = invokeExtensions(task, _context, containerOccurrence, [ container.Extensions ] )]
        [#local _context += containerDetails ]
        [#local _context += getFinalEnvironment(task, _context) ]

        [#-- validate fargate requirements from container context --]
        [#if solution.Engine == "fargate" ]
            [#local fargateInvalidConfig = false ]
            [#local fargateInvalidConfigMessage = [] ]

            [#if !( _context.MaximumMemory?has_content )  ]
                [#local fargateInvalidConfig = true ]
                [#local fargateInvalidConfigMessage += [ "Maximum memory must be assigned" ]]
            [/#if]

            [#if (_context.Privileged )]
                [#local fargateInvalidConfig = true ]
                [#local fargateInvalidConfigMessage += [ "Cannot run in priviledged mode" ] ]
            [/#if]

            [#if _context.ContainerNetworkLinks!{}?has_content ]
                [#local fargateInvalidConfig = true ]
                [#local fargateInvalidConfigMessage += [ "Cannot use Network Links" ] ]
            [/#if]

            [#if (_context.Hosts!{})?has_content ]
                [#local fargateInvalidConfig = true ]
                [#local fargateInvalidConfigMessage += [ "Cannot add host entries" ] ]
            [/#if]

            [#list _context.Volumes!{} as name,volume ]
                [#if volume.hostPath?has_content || volume.PersistVolume || ( volume.Driver != "local" && volume.Driver != "efs" ) ]
                    [#local fargateInvalidConfig = true ]
                    [#local fargateInvalidConfigMessage += [ "Can only use the local or efs driver and cannot reference host - volume ${name}" ] ]
                [/#if]
            [/#list]

            [#if fargateInvalidConfig ]
                [@fatal
                    message="Invalid Fargate configuration"
                    context=
                        {
                            "Description" : "Fargate containers only support the awsvpc network mode",
                            "ValidationErrors" : fargateInvalidConfigMessage
                        }
                    detail=solution
                /]
            [/#if]
        [/#if]

        [#local containers += [_context] ]
    [/#list]

    [#return containers]
[/#function]
