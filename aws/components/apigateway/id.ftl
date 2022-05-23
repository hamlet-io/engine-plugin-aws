[#ftl]
[@addResourceGroupInformation
    type=APIGATEWAY_COMPONENT_TYPE
    attributes=[
        {
            "Names" : "AccessLogging",
            "Children" : [
                {
                    "Names" : "Enabled",
                    "Types" : BOOLEAN_TYPE,
                    "Default" : true
                },
                {
                    "Names" : "aws:DestinationLink",
                    "Description" : "Destination for the Access logs. If not provided but AccessLogging is enabled, Access logs will be sent to CloudWatch.",
                    "AttributeSet" : LINK_ATTRIBUTESET_TYPE
                },
                {
                    "Names" : "aws:KinesisFirehose",
                    "Description" : "Send Access logs to a KinesisFirehose. By default, the Firehose destination is the OpsData DataBucket, but can be overwritten by specifying a DestinationLink.",
                    "Types" : BOOLEAN_TYPE,
                    "Default" : false
                },
                {
                    "Names" : "aws:KeepLogGroup",
                    "Description" : "Prevent the destruction of existing LogGroups when enabling KinesisFirehose.",
                    "Types" : BOOLEAN_TYPE,
                    "Default" : true
                },
                {
                    "Names" : "aws:LogFormat",
                    "Description" : "Log format control",
                    "Children" : [
                        {
                            "Names" : "Syntax",
                            "Types" : STRING_TYPE,
                            "Values" : ["text", "json"],
                            "Default" : "text"
                        }
                    ]
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
    prefixed=false
/]

[@addResourceGroupAttributeValues
    type=APIGATEWAY_COMPONENT_TYPE
    provider=AWS_PROVIDER
    extensions=[
        {
            "Names": "AuthorisationModel",
            "Types" : STRING_TYPE,
            "Values" : [ "shared:SIG4ORIP", "SIG4_OR_IP", "shared:SIG4ANDIP", "SIG4_AND_IP" ]
        }
    ]
/]