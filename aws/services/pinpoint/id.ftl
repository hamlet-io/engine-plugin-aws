[#ftl]

[#-- Resources --]
[#assign AWS_PINPOINT_RESOURCE_TYPE = "pinpoint"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_PINPOINT_SERVICE
    resource=AWS_PINPOINT_RESOURCE_TYPE
/]

[#assign AWS_PINPOINT_APNS_CHANNEL_RESOURCE_TYPE = "pinpointchannelapns"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_PINPOINT_SERVICE
    resource=AWS_PINPOINT_APNS_CHANNEL_RESOURCE_TYPE
/]

[#assign AWS_PINPOINT_APNS_SANDBOX_CHANNEL_RESOURCE_TYPE = "pinpointchannelapnssandbox"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_PINPOINT_SERVICE
    resource=AWS_PINPOINT_APNS_SANDBOX_CHANNEL_RESOURCE_TYPE
/]

[#assign AWS_PINPOINT_GCM_CHANNEL_RESOURCE_TYPE = "pinpointchannelgcm"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_PINPOINT_SERVICE
    resource=AWS_PINPOINT_GCM_CHANNEL_RESOURCE_TYPE
/]
