[#ftl]

[#assign AWS_PINPOINT_OUTPUT_MAPPINGS =
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
    resourceType=AWS_PINPOINT_RESOURCE_TYPE
    mappings=AWS_PINPOINT_OUTPUT_MAPPINGS
/]

[#macro createPinpointApp id name description="" tags={} dependencies=[]]
    [@cfResource
        id=id
        type="AWS::Pinpoint::App"
        properties=
        {
            "Name" : name
        } +
        attributeIfContent(
            "Description",
            description
        ) +
        attributeIfContent(
            "Tags",
            tags
        )
        outputs=AWS_PINPOINT_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]

[#macro createPinpointAPNSChannel id pinpointAppId certificate privateKey dependencies=[] ]
    [@cfResource
        id=id
        type="AWS::Pinpoint::APNSChannel"
        properties={
            "ApplicationId": getReference(pinpointAppId),
            "DefaultAuthenticationMethod" : "CERTIFICATE",
            "Certificate" : certificate,
            "PrivateKey" : privateKey
        }
        dependencies=dependencies
    /]
[/#macro]

[#macro createPinpointAPNSSandboxChannel id pinpointAppId certificate privateKey dependencies=[] ]
    [@cfResource
        id=id
        type="AWS::Pinpoint::APNSSandboxChannel"
        properties={
            "ApplicationId": getReference(pinpointAppId),
            "Certificate" : certificate,
            "DefaultAuthenticationMethod" : "CERTIFICATE",
            "PrivateKey" : privateKey
        }
        dependencies=dependencies
    /]
[/#macro]

[#macro createPinpointGCMChannel id pinpointAppId apiKey dependencies=[]]
    [@cfResource
        id=id
        type="AWS::Pinpoint::GCMChannel"
        properties={
            "ApplicationId" : getReference(pinpointAppId),
            "ApiKey": apiKey
        }
        dependencies=dependencies
    /]
[/#macro]
