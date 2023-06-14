[#ftl]

[@addExtension
    id="s3_cw_log_export_access"
    aliases=[
        "_s3_cw_log_export_access"
    ]
    description=[
        "Grants access to the logs.amazonaws.com principal to export logs in s3"
    ]
    supportedTypes=[
        BASELINE_DATA_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_s3_cw_log_export_access_deployment_setup occurrence ]

    [#-- context needs to provide the bucket name/arn/id --]
    [#local bucketReference = _context.BucketReference!"HamletFatal Missing bucket reference" ]

    [@Policy
        s3ReadBucketACLPermission(
            bucketReference,
            { "Service": "logs." + getRegion() + ".amazonaws.com" },
            {
                "StringEquals" : {
                    "aws:SourceAccount": [ {"Ref" : "AWS::AccountId"} ]
                },
                "ArnLike": {
                    "aws:SourceArn" : [
                        formatArn("aws", "logs", getRegion(), {"Ref" : "AWS::AccountId"}, "log-group:*")
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
            { "Service": "logs." + getRegion() + ".amazonaws.com" },
            {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control",
                    "aws:SourceAccount": [ {"Ref" : "AWS::AccountId"} ]
                },
                "ArnLike": {
                    "aws:SourceArn" : [
                        formatArn("aws", "logs", getRegion(), {"Ref" : "AWS::AccountId"}, "log-group:*")
                    ]
                }
            }
        )
    /]

[/#macro]
