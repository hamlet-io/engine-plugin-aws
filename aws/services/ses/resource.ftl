[#ftl]

[#assign AWS_SES_RECEIPT_RULESET_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        NAME_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_SES_RECEIPT_RULESET_RESOURCE_TYPE
    mappings=AWS_SES_RECEIPT_RULESET_OUTPUT_MAPPINGS
/]

[#macro createSESReceiptRuleSet id name dependencies=[] ]
    [@cfResource
        id=id
        type="AWS::SES::ReceiptRuleSet"
        properties=
            {
                "RuleSetName" : name
            }
        outputs=AWS_SES_RECEIPT_RULESET_OUTPUT_MAPPINGS
        dependencies=[]
    /]
[/#macro]

[#assign AWS_SES_RECEIPT_RULE_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        NAME_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_SES_RECEIPT_RULE_RESOURCE_TYPE
    mappings=AWS_SES_RECEIPT_RULE_OUTPUT_MAPPINGS
/]

[#assign AWS_SES_CONFIGSET_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        NAME_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_SES_CONFIGSET_RESOURCE_TYPE
    mappings=AWS_SES_CONFIGSET_OUTPUT_MAPPINGS
/]

[#macro createSESConfigSet id name dependencies=[]]
    [@cfResource
        id=id
        type="AWS::SES::ConfigurationSet"
        properties=
            {
                "Name" : name
            }
        outputs=AWS_SES_CONFIGSET_OUTPUT_MAPPINGS
        dependencies=[]
    /]
[/#macro]

[#assign AWS_SES_CONFIGSET_DEST_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_SES_CONFIGSET_DEST_RESOURCE_TYPE
    mappings=AWS_SES_CONFIGSET_DEST_OUTPUT_MAPPINGS
/]

[#macro createSesConfigSetEventDestination
        id
        configSetId
        matchingEventTypes
        destinationType
        enabled=true
        name=""
        topicId=""
        firehoseId=""
        firehoseDeliveryRoleId=""
        dependencies=[]
]

    [#local eventDestination = {
            "Enabled": enabled,
            "MatchingEventTypes": matchingEventTypes
        } +
        attributeIfContent(
            "Name",
            name
        )
    ]

    [#switch destinationType ]
        [#case "sns" ]
            [#local eventDestination = mergeObjects(
                eventDestination,
                {
                    "SnsDestination": {
                        "TopicARN": getArn(topicId)
                    }
                }
            )]
            [#break]

        [#case "firehose"]
            [#local eventDestination = mergeObjects(
                eventDestination,
                    {
                    "KinesisFirehoseDestination": {
                        "DeliveryStreamARN": getArn(firehoseId),
                        "IAMRoleARN": getArn(firehoseDeliveryRoleId)
                    }
                }
            )]
            [#break]

        [#default]
            [@fatal
                message="Invalid SNS Event Destination"
                context={
                    "ResourceId": id,
                    "DestinationType" : destinationType
                }
            /]
    [/#switch]

    [@cfResource
        id=id
        type="AWS::SES::ConfigurationSetEventDestination"
        properties={
            "ConfigurationSetName": getReference(configSetId),
            "EventDestination" : eventDestination
        }
        dependencies=dependencies
        outputs=AWS_SES_CONFIGSET_DEST_OUTPUT_MAPPINGS
    /]
[/#macro]

[#macro createSESReceiptRule id name ruleSetName actions=[] afterRuleName="" recipients=[] enabled=true scanEnabled=true tlsRequired=false dependencies=[] ]
    [@cfResource
        id=id
        type="AWS::SES::ReceiptRule"
        properties=
            {
                "RuleSetName" : ruleSetName,
                "Rule" : {
                    "Name" : name,
                    "Enabled" : enabled,
                    "ScanEnabled" : scanEnabled,
                    "TlsPolicy" : valueIfTrue("Require", tlsRequired, "Optional"),
                    "Recipients" : asArray(recipients),
                    "Actions" : asArray(actions)
                }
            } +
            attributeIfContent("After", afterRuleName)

        outputs=AWS_SES_RECEIPT_RULE_OUTPUT_MAPPINGS
        dependencies=[]
    /]
[/#macro]

[#function getSESReceiptS3Action bucketName prefix="" kmsIdOrArn="" topicIdOrArn="" ]
    [#return
        [
            {
                "S3Action" : {
                    "BucketName" : bucketName
                } +
                attributeIfContent("ObjectKeyPrefix", prefix) +
                attributeIfContent("KmsKeyArn", kmsIdOrArn, getArn(kmsIdOrArn)) +
                attributeIfContent("TopicArn", topicIdOrArn, getArn(topicIdOrArn))
            }
        ]
    ]
[/#function]

[#function getSESReceiptStopAction scope="RuleSet" topicIdOrArn="" ]
    [#return
        [
            {
                "StopAction" : {
                    "Scope" : scope
                } +
                attributeIfContent("TopicArn", topicIdOrArn, getArn(topicIdOrArn))
            }
        ]
    ]
[/#function]

[#function getSESReceiptLambdaAction lambdaId event=true topicIdOrArn="" ]
    [#return
        [
            {
                "LambdaAction" : {
                    "FunctionArn" : getArn(lambdaId),
                    "InvocationType" : valueIfTrue("Event", event, "RequestResponse")
                } +
                attributeIfContent("TopicArn", topicIdOrArn, getArn(topicIdOrArn))
            }
        ]
    ]
[/#function]

[#function getSESReceiptBounceAction sender message smtpyReplyCode statusCode topicIdOrArn="" ]
    [#return
        [
            {
                "BounceAction" : {
                    "Message" : message,
                    "Sender" : sender,
                    "SmtpReplyCode" : smtpyReplyCode,
                    "StatusCode": statusCode
                } +
                attributeIfContent("TopicArn", topicIdOrArn, getArn(topicIdOrArn))
            }
        ]
    ]
[/#function]

[#assign AWS_SES_RECEIPT_IP_FILTER_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_SES_RECEIPT_FILTER_RESOURCE_TYPE
    mappings=AWS_SES_RECEIPT_IP_FILTER_OUTPUT_MAPPINGS
/]

[#macro createSESReceiptIPFilter id name cidr allow=true]
    [@cfResource
        id=id
        type="AWS::SES::ReceiptFilter"
        properties=
            {
                "Filter" : {
                    "Name" : name,
                    "IpFilter" : {
                        "Cidr" : cidr,
                        "Policy" : valueIfTrue("Allow", allow, "Block")
                    }
                }
            }

        outputs=AWS_SES_RECEIPT_FILTER_OUTPUT_MAPPINGS
        dependencies=[]
    /]
[/#macro]

[#function expandSESRecipients recipients=[] domains=[] ]
    [#local result = [] ]
    [#list asArray(domains) as domain]
        [#list asArray(recipients) as recipient]
            [#switch recipient]
                [#case ""]
                [#case "."]
                    [#local prefix = recipient]
                    [#break]
                [#case "*"]
                    [#local prefix = ""]
                    [#break]
                [#default]
                    [#local prefix = recipient + "@" ]
                    [#break]
            [/#switch]
            [#local result += [ prefix + formatDomainName(domain)] ]
        [/#list]
    [/#list]
    [#return result]
[/#function]
