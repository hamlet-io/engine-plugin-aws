[#ftl]

[#-- Resources --]
[#assign AWS_AUTOSCALING_APP_TARGET_RESOURCE_TYPE = "autoscalingapptarget" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_AUTOSCALING_SERVICE
    resource=AWS_AUTOSCALING_APP_TARGET_RESOURCE_TYPE
/]
[#assign AWS_AUTOSCALING_APP_POLICY_RESOURCE_TYPE = "autoscalingapppolicy" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_AUTOSCALING_SERVICE
    resource=AWS_AUTOSCALING_APP_POLICY_RESOURCE_TYPE
/]
[#assign AWS_AUTOSCALING_EC2_POLICY_RESOURCE_TYPE = "autoscalingec2policy" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_AUTOSCALING_SERVICE
    resource=AWS_AUTOSCALING_EC2_POLICY_RESOURCE_TYPE
/]
[#assign AWS_AUTOSCALING_EC2_SCHEDULE_RESOURCE_TYPE = "autoscalingec2schedule" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_AUTOSCALING_SERVICE
    resource=AWS_AUTOSCALING_EC2_SCHEDULE_RESOURCE_TYPE
/]

[#function formatDependentAutoScalingAppPolicyId resourceId extensions... ]
    [#return formatDependentResourceId(
                AWS_AUTOSCALING_APP_POLICY_RESOURCE_TYPE,
                resourceId,
                extensions)]
[/#function]

[#function formatDependentAutoScalingEc2PolicyId resourceId extensions... ]
    [#return formatDependentResourceId(
                AWS_AUTOSCALING_EC2_POLICY_RESOURCE_TYPE,
                resourceId,
                extensions)]
[/#function]

[#function formatDependentAutoScalingEc2ScheduleId resourceId extensions... ]
    [#return formatDependentResourceId(
                AWS_AUTOSCALING_EC2_SCHEDULE_RESOURCE_TYPE,
                resourceId,
                extensions)]
[/#function]
