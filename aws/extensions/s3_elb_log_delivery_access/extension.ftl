[#ftl]

[@addExtension
    id="s3_elb_log_delivery_access"
    aliases=[
        "_s3_elb_log_delivery_access"
    ]
    description=[
        "Grants access to the ELB to deliver logs in s3"
    ]
    supportedTypes=[
        BASELINE_DATA_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_s3_elb_log_delivery_access_deployment_setup occurrence ]

    [#-- context needs to provide the bucket name/arn/id --]
    [#local bucketReference = _context.BucketReference!"HamletFatal Missing bucket reference" ]

    [@Policy
        [#-- The legacy approach before optional regions --]
        getS3Statement(
            [
                "s3:PutObject"
            ],
            bucketReference,
            "AWSLogs",
            "*",
            {
                "AWS": "arn:aws:iam::" + getRegionObject().Accounts["ELB"] + ":root"
            }
        ) +
        [#-- LB logging for new regions --]
        [#-- https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html#attach-bucket-policy --]
        getS3Statement(
            [
                "s3:PutObject"
            ],
            bucketReference,
            "AWSLogs",
            "*",
            {
                "Service": "logdelivery.elasticloadbalancing.amazonaws.com"
            },
            {
                "StringEquals" : {
                    "aws:SourceAccount": [ {"Ref" : "AWS::AccountId"} ]
                }
            }
        )
    /]

[/#macro]
