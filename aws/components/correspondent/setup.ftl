[#ftl]

[#macro aws_correspondent_cf_deployment_generationcontract occurrence ]
    [@addDefaultGenerationContract subsets=["template"] /]
[/#macro]

[#macro aws_correspondent_cf_deployment occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]

    [#local correspondentId = resources["correspondent"].Id ]
    [#local correspondentName = resources["correspondent"].Name ]

    [@createPinpointApp
        id=correspondentId
        name=correspondentName
        tags=getOccurrenceTags(occurrence)
    /]

    [#list (occurrence.Occurrences![])?filter(x -> x.Configuration.Solution.Enabled && x.Core.Type == CORRESPONDENT_CHANNEL_COMPONENT_TYPE ) as subOccurrence]

        [#local core = subOccurrence.Core ]
        [#local solution = subOccurrence.Configuration.Solution ]
        [#local resources = subOccurrence.State.Resources ]

        [#local channelId = resources["channel"].Id ]

        [#local linkTargets = getLinkTargets(occurrence, solution.Links )]

        [#switch solution.Engine ]
            [#case "apns"]
                [@createPinpointAPNSChannel
                    id=channelId
                    pinpointAppId=correspondentId
                    certificate=(solution["engine:APNS"].Certificate)!"HamletFatal: engine:APNS.Certificate configuration required for APNS Channel"
                    privateKey=(solution["engine:APNS"].PrivateKey)!"HamletFatal: engine:APNS.PrivateKey configuration required for APNS Channel"
                /]
                [#break]
            [#case "apns_sandbox"]
                [@createPinpointAPNSSandboxChannel
                    id=channelId
                    pinpointAppId=correspondentId
                    certificate=(solution["engine:APNSSandbox"].Certificate)!"HamletFatal: engine:APNSSandbox.Certificate configuration required for APNS Channel"
                    privateKey=(solution["engine:APNSSandbox"].PrivateKey)!"HamletFatal: engine:APNSSandbox.PrivateKey configuration required for APNS Channel"
                /]
                [#break]

            [#case "firebase"]
                [@createPinpointGCMChannel
                    id=channelId
                    pinpointAppId=correspondentId
                    apiKey=(solution["engine:Firebase"].APIKey)!"HamletFatal: engine:Firebase.APIKey configuration required for APNS Channel"
                /]
                [#break]

            [#default]
                [@fatal
                    message="Invalid correspondent channel engine for AWS"
                    detail={
                        "CorrespondentId" : occurrence.Core.RawId,
                        "ChannelId" : core.RawId,
                        "Engine" : solution.Engine
                    }
                /]
        [/#switch]
    [/#list]
[/#macro]
