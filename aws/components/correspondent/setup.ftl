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

    [#if deploymentSubsetRequired(CORRESPONDENT_COMPONENT_TYPE, true)]

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
                    [#switch solution.AuthMethod ]
                        [#case "certificate"]
                            [@createPinpointAPNSChannel
                                id=channelId
                                pinpointAppId=correspondentId
                                certificate=(solution["engine:APNS"].Certificate)!"HamletFatal: engine:APNS.Certificate configuration required for APNS Channel"
                                privateKey=(solution["engine:APNS"].PrivateKey)!"HamletFatal: engine:APNS.PrivateKey configuration required for APNS Channel"
                            /]
                            [#break]
                        [#case "token"]
                            [@createPinpointAPNSChannelWithTokenKey
                                id=channelId
                                pinpointAppId=correspondentId
                                tokenKeyId=(solution["engine:APNS"].TokenKeyId)!"HamletFatal: engine:APNS.TokenKeyId configuration required for APNS Channel"
                                bundleId=(solution["engine:APNS"].BundleId)!"HamletFatal: engine:APNS.BundleId configuration required for APNS Channel"
                                teamId=(solution["engine:APNS"].TeamId)!"HamletFatal: engine:APNS.TeamId configuration required for APNS Channel"
                                tokenKey=(solution["engine:APNS"].TokenKey)!"HamletFatal: engine:APNS.TokenKey configuration required for APNS Channel"
                            /]
                            [#break]
                    [/#switch]
                    [#break]
                [#case "apns_sandbox"]
                    [#switch solution.AuthMethod ]
                        [#case "certificate"]
                            [@createPinpointAPNSSandboxChannel
                                id=channelId
                                pinpointAppId=correspondentId
                                certificate=(solution["engine:APNSSandbox"].Certificate)!"HamletFatal: engine:APNSSandbox.Certificate configuration required for APNS Sandbox Channel"
                                privateKey=(solution["engine:APNSSandbox"].PrivateKey)!"HamletFatal: engine:APNSSandbox.PrivateKey configuration required for APNS Sandbox Channel"
                            /]
                            [#break]
                        [#case "token"]
                            [@createPinpointAPNSSandboxChannelWithTokenKey
                                id=channelId
                                pinpointAppId=correspondentId
                                tokenKeyId=(solution["engine:APNSSandbox"].TokenKeyId)!"HamletFatal: engine:APNSSandbox.TokenKeyId configuration required for APNS Sandbox Channel"
                                bundleId=(solution["engine:APNSSandbox"].BundleId)!"HamletFatal: engine:APNSSandbox.BundleId configuration required for APNS Sandbox Channel"
                                teamId=(solution["engine:APNSSandbox"].TeamId)!"HamletFatal: engine:APNSSandbox.TeamId configuration required for APNS Sandbox Channel"
                                tokenKey=(solution["engine:APNSSandbox"].TokenKey)!"HamletFatal: engine:APNSSandbox.TokenKey configuration required for APNS Sandbox Channel"
                            /]
                            [#break]
                    [/#switch]
                    [#break]

                [#case "firebase"]
                    [#switch solution.AuthMethod ]
                        [#case "apikey"]
                            [@createPinpointGCMChannel
                                id=channelId
                                pinpointAppId=correspondentId
                                apiKey=(solution["engine:Firebase"].APIKey)!"HamletFatal: engine:Firebase.APIKey configuration required for GCM Channel"
                            /]
                            [#break]
                        [#case "token"]
                            [@createPinpointGCMChannelWithToken
                                id=channelId
                                pinpointAppId=correspondentId
                                token=(solution["engine:Firebase"].Token)!"HamletFatal: engine:Firebase.Token configuration required for GCM Channel"
                            /]
                            [#break]
                    [/#switch]
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

    [/#if]
[/#macro]
