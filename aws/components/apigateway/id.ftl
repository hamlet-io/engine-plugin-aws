[#ftl]
[@addResourceGroupInformation
    type=APIGATEWAY_COMPONENT_TYPE
    attributes=[
        {
            "Names" : "AccessLogging",
            "Children" : [
                {
                    "Names" : "DestinationLink",
                    "Description" : "Destination for the Access logs. If not provided but AccessLogging is enabled, Access logs will be sent to CloudWatch.",
                    "Children" : linkChildrenConfiguration
                },
                {
                    "Names" : "KinesisFirehose",
                    "Description" : "Send Access logs to a KinesisFirehose. By default, the Firehose destination is the OpsData DataBucket, but can be overwritten by specifying a DestinationLink.",
                    "Type" : BOOLEAN_TYPE,
                    "Default" : false
                },
                {
                    "Names" : "KeepLogGroup",
                    "Description" : "Prevent the destruction of existing LogGroups when enabling KinesisFirehose.",
                    "Type" : BOOLEAN_TYPE,
                    "Default" : true
                }
            ]
        }
    ]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_APIGATEWAY_SERVICE,
            AWS_CLOUDWATCH_SERVICE,
            AWS_CLOUDFRONT_SERVICE,
            AWS_WEB_APPLICATION_FIREWALL_SERVICE,
            AWS_ROUTE53_SERVICE,
            AWS_CERTIFICATE_MANAGER_SERVICE,
            AWS_KINESIS_SERVICE,
            AWS_IDENTITY_SERVICE
        ]
/]