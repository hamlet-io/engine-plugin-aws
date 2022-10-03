[#ftl]

[@addExtension
    id="datacatalog_aws_networkfirewall_location"
    aliases=[
        "_datacatalog_aws_networkfirewall_location"
    ]
    description=[
        "Set the location for AWS Services which log to the AWSLogs dir"
    ]
    supportedTypes=[
        DATACATALOG_TABLE_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_datacatalog_aws_networkfirewall_location_deployment_setup occurrence ]

    [#assign _context = mergeObjects(
        _context,
        {
            "LocationPath": {
                "Fn::Sub" : [
                    r's3://${BucketName}/AWSLogs/${AWS::AccountId}/network-firewall/',
                    {
                        "BucketName": (_context.SourceLink.State.Attributes.NAME)!""
                    }
                ]
            }
        }
    )]

[/#macro]
