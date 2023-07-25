[#ftl]

[#assign AWS_S3_RESOURCE_TYPE = "s3" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_SIMPLE_STORAGE_SERVICE
    resource=AWS_S3_RESOURCE_TYPE
/]
[#assign AWS_S3_BUCKET_POLICY_RESOURCE_TYPE="bucketpolicy" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_SIMPLE_STORAGE_SERVICE
    resource=AWS_S3_BUCKET_POLICY_RESOURCE_TYPE
/]

[#function formatS3Id ids...]
    [#return formatResourceId(
            AWS_S3_RESOURCE_TYPE,
            ids)]
[/#function]

[#function formatSegmentS3Id type extensions...]
    [#return formatSegmentResourceId(
                AWS_S3_RESOURCE_TYPE,
                type,
                extensions)]
[/#function]

[#function formatOccurrenceS3Id occurrence extensions...]
    [#return formatComponentResourceId(
                AWS_S3_RESOURCE_TYPE,
                occurrence.Core.Tier,
                occurrence.Core.Component,
                occurrence,
                extensions)]
[/#function]

[#function formatAccountS3Id type extensions...]
    [#return formatAccountResourceId(
                AWS_S3_RESOURCE_TYPE,
                type,
                extensions)]
[/#function]

[#function formatBucketPolicyId ids...]
    [#return formatResourceId(
                AWS_S3_BUCKET_POLICY_RESOURCE_TYPE,
                ids)]
[/#function]

[#function formatDependentBucketPolicyId resourceId extensions...]
    [#return formatDependentResourceId(
                AWS_S3_BUCKET_POLICY_RESOURCE_TYPE,
                resourceId,
                extensions)]
[/#function]

[#function formatS3NotificationPolicyId bucketId destinationId]
    [#return formatDependentPolicyId(
                bucketId,
                destinationId)]
[/#function]
