[#ftl]

[#assign AWS_CLOUDTRAIL_TRAIL_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "Attribute" : "Arn"
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_CLOUDTRAIL_TRAIL_RESOURCE_TYPE
    mappings=AWS_CLOUDTRAIL_TRAIL_OUTPUT_MAPPINGS
/]

[#function getCloudTrailTrailDataResource resourceType arnMatch ]
    [#switch resourceType ]
        [#case AWS_LAMBDA_FUNCTION_RESOURCE_TYPE]
        [#case "AWS::Lambda::Function"]
            [#local resourceType = "AWS::Lambda::Function"]
            [#if arnMatch?is_string && arnMatch == "_all__"]
                [#local arnMatch = [ "arn:aws:lambda"]]
            [/#if]
            [#break]

        [#case AWS_S3_RESOURCE_TYPE]
        [#case "AWS::S3::Object"]
            [#local resourceType = "AWS::S3::Object"]
            [#if arnMatch?is_string && arnMatch == "_all__"]
                [#local arnMatch = [ "arn:aws:s3"]]
            [/#if]

            [#break]

        [#case AWS_DYNAMODB_TABLE_RESOURCE_TYPE]
        [#case "AWS::DynamoDB::Table"]
            [#local resourceType = "AWS::DynamoDB::Table"]
            [#if arnMatch?is_string && arnMatch == "_all__"]
                [#local arnMatch = [ "arn:aws:dynamodb"]]
            [/#if]
            [#break]
    [/#switch]

    [#return {
        "Type": resourceType,
        "Values": arnMatch
    }]
[/#function]

[#function getCloudTrailTrailEventSelector
    managementEvents=true
    excludedManagementSources=[]
    dataResources=[]
    readWriteType="" ]

    [#return {
        "IncludeManagementEvents": managementEvents
    } +
    attributeIfContent(
        "ReadWriteType",
        readWriteType
    ) +
    attributeIfContent(
        "ExcludeManagementEventSources",
        excludedManagementSources
    ) +
    attributeIfContent(
        "DataResources",
        dataResources
    )]
[/#function]

[#function getCloudTrailTrailInsightSelectors insightTypes=[] ]
    [#local results = []]

    [#list insightTypes as insightType ]
        [#switch insightType]
            [#case "ApiCallRateInsight"]
            [#case "CallRate"]
                [#local results = combineEntities(
                    results,
                    ["ApiCallRateInsight"],
                    UNIQUE_COMBINE_BEHAVIOUR
                )]
                [#break]
            [#case "ApiErrorRateInsight"]
            [#case "ErrorRate"]
                [#local results = combineEntities(
                    results,
                    ["ApiErrorRateInsight"],
                    UNIQUE_COMBINE_BEHAVIOUR
                )]
                [#break]
        [/#switch]
    [/#list]
    [#return results?map(x -> {"InsightType": x})]
[/#function]

[#macro createCloudTrailTrail
        id name
        s3BucketId
        s3KeyPrefix=""
        enabled=true
        organizationTrail=false
        multiRegion=false
        logFileValidation=false
        includeGlobalServices=false
        eventSelectors=[]
        insightSelectors=[]
        cloudWatchLogGroupId=""
        cloudWatchLogsRoleId=""
        snsDeliveryTopicId=""
        kmsKeyId=""
        tags=[]
        dependencies=[] ]

    [@cfResource
        id=id
        type="AWS::CloudTrail::Trail"
        properties={
            "TrailName": name,
            "IsLogging": enabled,
            "S3BucketName": getReference(s3BucketId, NAME_ATTRIBUTE_TYPE)
        } +
        attributeIfContent(
            "S3KeyPrefix",
            s3KeyPrefix
        ) +
        attributeIfContent(
            "KMSKeyId",
            getArn(kmsKeyId)
        ) +
        attributeIfTrue(
            "IsMultiRegionTrail",
            multiRegion,
            multiRegion
        ) +
        attributeIfTrue(
            "IsOrganizationTrail",
            organizationTrail,
            organizationTrail
        ) +
        attributeIfTrue(
            "EnableLogFileValidation",
            logFileValidation,
            logFileValidation
        ) +
        attributeIfContent(
            "EventSelectors",
            eventSelectors
        ) +
        attributeIfContent(
            "CloudWatchLogsLogGroupArn",
            getArn(cloudWatchLogGroupId)
        ) +
        attributeIfContent(
            "CloudWatchLogsRoleArn",
            getArn(cloudWatchLogsRoleId)
        ) +
        attributeIfTrue(
            "IncludeGlobalServiceEvents",
            includeGlobalServices,
            includeGlobalServices
        ) +
        attributeIfContent(
            "SNSTopicName",
            getReference(snsDeliveryTopicId)
        ) +
        attributeIfContent(
            "InsightSelectors",
            insightSelectors
        )
        tags=tags
    /]
[/#macro]
