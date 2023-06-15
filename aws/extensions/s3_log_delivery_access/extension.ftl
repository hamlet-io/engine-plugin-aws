[#ftl]

[@addExtension
    id="s3_log_delivery_access"
    aliases=[
        "_s3_log_delivery_access"
    ]
    description=[
        "Grants access to the delivery.logs.amazonaws.com principal to save logs in s3"
    ]
    supportedTypes=[
        BASELINE_DATA_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_s3_log_delivery_access_deployment_setup occurrence ]

    [#-- context needs to provide the bucket name/arn/id --]
    [#local bucketReference = _context.BucketReference!"HamletFatal Missing bucket reference" ]

    [@Policy
        s3ReadBucketACLPermission(
            bucketReference,
            { "Service": "delivery.logs.amazonaws.com" },
            {
                "StringEquals" : {
                    "aws:SourceAccount": [ {"Ref" : "AWS::AccountId"} ]
                },
                "ArnLike": {
                    "aws:SourceArn" : [
                        formatArn("aws", "logs", getRegion(), {"Ref" : "AWS::AccountId"}, "*")
                    ]
                }
            }
        ) +
        s3ListBucketPermission(
            bucketReference,
            { "Service": "delivery.logs.amazonaws.com" },
            {
                "StringEquals" : {
                    "aws:SourceAccount": [ {"Ref" : "AWS::AccountId"} ]
                },
                "ArnLike": {
                    "aws:SourceArn" : [
                        formatArn("aws", "logs", getRegion(), {"Ref" : "AWS::AccountId"}, "*")
                    ]
                }
            }
        ) +
        getS3Statement(
            [
                "s3:PutObject"
            ],
            bucketReference,
            "",
            "*",
            { "Service": "delivery.logs.amazonaws.com" },
            {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control",
                    "aws:SourceAccount": [ {"Ref" : "AWS::AccountId"} ]
                },
                "ArnLike": {
                    "aws:SourceArn" : [
                        formatArn("aws", "logs", getRegion(), {"Ref" : "AWS::AccountId"}, "*")
                    ]
                }
            }
        )
    /]

[/#macro]
