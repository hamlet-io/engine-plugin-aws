[#ftl]

[#function formatSegmentBucketName segmentSeed extensions...]
    [#return
        formatName(
            valueIfTrue(
                (tenantObject.Name)!"",
                (segmentObject.S3.IncludeTenant)!false,
                ""),
            formatSegmentFullName(extensions),
            segmentSeed)]
[/#function]

[#function formatOccurrenceBucketName occurrence extensions...]
    [#return
        formatName(
            valueIfTrue(
                (tenantObject.Name)!"",
                (segmentObject.S3.IncludeTenant)!false,
                ""),
            formatComponentFullName(
                occurrence.Core.Tier,
                occurrence.Core.Component,
                occurrence
                extensions),
            segmentSeed())]
[/#function]

[#function formatAccountS3PrimaryBucketName bucketType ]
    [#assign existingName = getExistingReference(formatAccountS3Id(bucketType), NAME_ATTRIBUTE_TYPE, getCLOSegmentRegion() )]
    [#return valueIfContent(
                existingName,
                existingName,
                formatName("account", bucketType, accountObject.Seed ))]
[/#function]


[#function formatAccountS3ReplicaBucketName bucketType region ]
    [#return formatAccountS3PrimaryBucketName(bucketType)?ensure_ends_with("-" + region)]
[/#function]
