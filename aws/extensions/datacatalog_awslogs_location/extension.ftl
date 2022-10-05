[#ftl]

[@addExtension
    id="datacatalog_awslogs_location"
    aliases=[
        "_datacatalog_awslogs_location"
    ]
    description=[
        "Set the location for AWS Services which log to the AWSLogs dir"
    ]
    supportedTypes=[
        DATACATALOG_TABLE_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_datacatalog_awslogs_location_deployment_setup occurrence ]

    [#assign _context = mergeObjects(
        _context,
        {
            "LocationPath": {
                "Fn::Sub" : [
                    r's3://${BucketName}/AWSLogs/${AWS::AccountId}/${ServiceName}/${AWS::Region}',
                    {
                        "BucketName": (_context.SourceLink.State.Attributes.NAME)!"",
                        "ServiceName": (_context.DefaultEnvironment["SERVICE_NAME"])!""
                    }
                ]
            }
        }
    )]

[/#macro]
