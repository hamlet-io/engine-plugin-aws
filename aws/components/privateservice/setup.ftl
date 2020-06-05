[#ftl]
[#macro aws_privateservice_cf_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract subsets="template" /]
[/#macro]

[#macro aws_privateservice_cf_setup_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]

    [#local vpcEndpointServiceId = resources["vpcEndpointService"].Id ]
    [#local vpcEndpointPermissionId = resources["vpcEndpointServicePermission"].Id ]

    [#local loadBalancerIds = [] ]

    [#list solution.Links as id,link]
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

            [#switch linkTargetCore.Type]
                [#case LB_COMPONENT_TYPE ]
                    [#if linkTargetConfiguration.Solution.Engine == "network" ]
                        [#local loadBalancerIds += [ linkTargetResources["lb"].Id ]]
                    [#else]
                        [@fatal
                            message="Invalid LB engine - only network supported"
                            context={
                                "Link" : {
                                    id : link
                                },
                                "Engine" : linkTargetConfiguration.Solution.Engine
                            }
                        /]
                    [/#if]
                    [#break]

            [/#switch]
        [/#if]
    [/#list]

    [#if deploymentSubsetRequired(PRIVATE_SERVICE_COMPONENT_TYPE, true)]
        [#if ! loadBalancerIds?has_content ]

            [@fatal
                message="No Network Load Balancers found - at least one link to a network load balancer required"
                context={
                    "Links" : solution.Links
                }
            /]

        [/#if]

        [@createVPCEndpointService
            id=vpcEndpointServiceId
            loadBalancerIds=loadBalancerIds
            acceptanceRequired=solution.Sharing.ApprovalRequired
        /]

        [@createVPCEndpointServicePermission
            id=vpcEndpointPermissionId
            vpcEndpointServiceId=vpcEndpointServiceId
            principalArns=solution.Sharing.Principals
        /]
    [/#if]

    [#list solution.ConnectionAlerts as alertId,connectionAlert ]

        [#local connectionEvents = connectionAlert.Events ]

        [#list connectionAlert.Links as linkId,link ]
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

                [#local vpcEndpointNotificationId = resources["vpcEndpointNotification" + alertId + linkId].Id ]

                [#switch linkTargetCore.Type]
                    [#case TOPIC_COMPONENT_TYPE ]

                        [#if deploymentSubsetRequired(PRIVATE_SERVICE_COMPONENT_TYPE, true)]
                            [@createVPCEndpointServiceNotification
                                id=vpcEndpointNotificationId
                                events=connectionEvents
                                notificationEndpointId=linkTargetAttributes["ARN"]
                                vpcEndpointServiceId=vpcEndpointServiceId
                            /]
                        [/#if]
                        [#break]
                [/#switch]
            [/#if]
        [/#list]
    [/#list]
[/#macro]
