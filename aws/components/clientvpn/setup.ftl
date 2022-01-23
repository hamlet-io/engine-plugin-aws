[#ftl]
[#macro aws_clientvpn_cf_deployment_generationcontract occurrence ]
    [@addDefaultGenerationContract subsets=["template"] /]
[/#macro]

[#macro aws_clientvpn_cf_deployment occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local resources = occurrence.State.Resources]
    [#local solution = occurrence.Configuration.Solution ]

    [#local vpnEndpointId = resources["endpoint"].Id]
    [#local vpnEndpointName = resources["endpoint"].Name]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "Encryption" ] )]
    [#local kmsKeyId = baselineComponentIds["Encryption"]]

    [#local certificateObject = getCertificateObject( solution.Certificate ) ]
    [#local hostName = getHostName(certificateObject, occurrence) ]
    [#local primaryDomainObject = getCertificatePrimaryDomain(certificateObject) ]
    [#local certificateId = formatDomainCertificateId(certificateObject, hostName) ]

    [#if ! getExistingReference(certificateId)?has_content ]
        [@fatal
            message="Certificate not found for domain name"
            detail="Ensure that an ACM based certificate has been created"
            context={
                "Component" : core.RawId,
                "CertificateConfiguration" : solution.Certificate,
                "ExpectedCertificateId" : certificateId
            }
        /]
    [/#if]

    [#local loggingProfile = getLoggingProfile(occurrence)]

    [#local occurrenceNetwork = getOccurrenceNetwork(occurrence) ]
    [#local networkLink = occurrenceNetwork.Link!{} ]

    [#local networkLinkTarget = getLinkTarget(occurrence, networkLink ) ]

    [#if ! networkLinkTarget?has_content ]
        [@fatal message="Network could not be found" context=networkLink /]
        [#return]
    [/#if]

    [#local networkConfiguration = networkLinkTarget.Configuration.Solution]
    [#local networkResources = networkLinkTarget.State.Resources ]

    [#local vpcId = networkResources["vpc"].Id ]

    [#local lgId = ""]
    [#local lgName = ""]
    [#local lgStreamName = "" ]

    [#if solution.Logging ]

        [#local lgId = resources["logging"]["lg"].Id ]
        [#local lgName = resources["logging"]["lg"].Name ]
        [#local lgStreamId = resources["logging"]["lgstream"].Id ]
        [#local lgStreamName = resources["logging"]["lgstream"].Name ]

        [#-- Add CloudWatch LogGroup --]
        [@setupLogGroup
            occurrence=occurrence
            logGroupId=lgId
            logGroupName=lgName
            loggingProfile=loggingProfile
            kmsKeyId=kmsKeyId
        /]

        [@createLogStream
            id=lgStreamId
            name=lgStreamName
            logGroup=getReference(lgId)
        /]

    [/#if]

    [#if deploymentSubsetRequired(CLIENTVPN_COMPONENT_TYPE, true)]

        [#local authProviderType = ""]
        [#local directoryId = ""]
        [#local samlProviderId = ""]
        [#local samlSelfServiceProviderId = ""]

        [#local authProviderLink = getLinkTarget(occurrence, solution.Authentication.Provider.Link, true, true)]

        [#if authProviderLink?has_content ]
            [#switch authProviderLink.Core.Type ]
                [#case DIRECTORY_COMPONENT_TYPE ]
                    [#switch authProviderLink.Configuration.Solution.Engine]
                        [#case "Simple"]
                        [#case "ActiveDirectory" ]
                            [#local directoryId = authProviderLink.State.Resources["directory"].Id ]
                            [#break]
                        [#case "aws:ADConnector"]
                            [#local directoryId = authProviderLink.State.Resources["connector"].Id ]
                            [#break]
                    [/#switch]

                    [#local authProviderType = "directory" ]
                    [#break]
                [#default]
                    [@fatal
                        message="VPN Client does not support the authentication provider"
                        context={
                            "ProviderLink" : solution.Authentication.Provider.Link
                        }

                    /]
            [/#switch]
        [/#if]

        [#local authOptions = getClientVPNAuthenticationOption(
            authProviderType,
            directoryId,
            samlProviderId,
            samlSelfServiceProviderId
        )]

        [@createClientVPNEndpoint
            id=vpnEndpointId
            name=vpnEndpointName
            tags=getOccurrenceCoreTags(occurrence, vpnEndpointName)
            authenticationOptions=authOptions
            clientCidrBlock=solution.Network.ClientCIDR
            connectionLogging=solution.Logging
            selfServicePortal=solution.SelfServicePortal
            splitTunnel=solution.Network.SplitTunnel
            certificateId=certificateId
            lgId=lgId
            lgStreamId=lgStreamId
            vpcId=vpcId
            port=ports[solution.Port]
            dnsServers=[]
        /]

        [#list getZones() as zone ]

            [#local zoneAssocId = resources["zoneResources"][zone.Id]["networkassoc"].Id]
            [#local zoneAssocName = resources["zoneResources"][zone.Id]["networkassoc"].Name]

            [@createClientVPNTargetNetworkAssociation
                id=zoneAssocId
                vpnClientId=vpnEndpointId
                subnetId=getSubnets(core.Tier, networkResources, zone.Id, false, false)[0]
            /]

            [#list getGroupCIDRs(solution.Network.Destinations.IPAddressGroups) as cidr ]
                [#local cidrId = replaceAlphaNumericOnly(cidr)]
                [@createClientVPNRoute
                    id=resources["zoneResources"][zone.Id][formatName("route", cidrId)].Id
                    name=resources["zoneResources"][zone.Id][formatName("route", cidrId)].Name
                    vpnClientId=vpnEndpointId
                    destinationCIDR=cidr
                    subnetId=getSubnets(core.Tier, networkResources, zone.Id, false, false)[0]
                    dependencies=[
                        zoneAssocId
                    ]
                /]
            [/#list]
        [/#list]


        [#list solution.AuthorisationRules as id, authorisationRule ]

            [#list getGroupCIDRs(authorisationRule.Destinations.IPAddressGroups) as cidr]

                [#local cidrId = replaceAlphaNumericOnly(cidr) ]
                [@createClientVPNAuthorizationRule
                    id=resources["authorisationRules"][id][cidrId]["rule"].Id
                    name=resources["authorisationRules"][id][cidrId]["rule"].Name
                    vpnClientId=vpnEndpointId
                    targetCIDR=cidr
                    groupCondition=authorisationRule.Condition
                    groupName=(authorisationRule["condition:Group"].GroupId)!""
                /]
            [/#list]
        [/#list]
    [/#if]
[/#macro]
