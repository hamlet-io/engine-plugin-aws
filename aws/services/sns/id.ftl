[#ftl]

[#-- Resources --]
[#assign AWS_SNS_TOPIC_RESOURCE_TYPE = "snstopic"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_SIMPLE_NOTIFICATION_SERVICE
    resource=AWS_SNS_TOPIC_RESOURCE_TYPE
/]

[#assign AWS_SNS_TOPIC_POLICY_RESOURCE_TYPE = "snstopicpolicy" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_SIMPLE_NOTIFICATION_SERVICE
    resource=AWS_SNS_TOPIC_RESOURCE_TYPE
/]

[#assign AWS_SNS_SUBSCRIPTION_RESOURCE_TYPE = "snssub"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_SIMPLE_NOTIFICATION_SERVICE
    resource=AWS_SNS_SUBSCRIPTION_RESOURCE_TYPE
/]
[#assign AWS_SNS_PLATFORMAPPLICATION_RESOURCE_TYPE = "snsplatformapp" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_SIMPLE_NOTIFICATION_SERVICE
    resource=AWS_SNS_PLATFORMAPPLICATION_RESOURCE_TYPE
/]

[#function formatSNSTopicId ids...]
    [#return formatResourceId(
                AWS_SNS_TOPIC_RESOURCE_TYPE,
                ids)]
[/#function]

[#function formatDependentSNSTopicId resourceId extensions...]
    [#return formatDependentResourceId(
                AWS_SNS_TOPIC_RESOURCE_TYPE,
                resourceId,
                extensions)]
[/#function]

[#function formatSegmentSNSTopicId extensions...]
    [#return formatSegmentResourceId(
                AWS_SNS_TOPIC_RESOURCE_TYPE,
                extensions)]
[/#function]


[#function formatDependentSNSSubscriptionId resourceId extensions...]
    [#return formatDependentResourceId(
                AWS_SNS_SUBSCRIPTION_RESOURCE_TYPE,
                resourceId,
                extensions)]
[/#function]
