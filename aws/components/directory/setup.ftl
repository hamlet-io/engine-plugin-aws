[#ftl]
[#macro aws_directory_cf_deployment_generationcontract occurrence ]
    [@addDefaultGenerationContract subsets=[ "template", "epilogue" ] /]
[/#macro]

[#macro aws_directory_cf_deployment occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#-- Component State helpers --]
    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "Encryption" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local cmkKeyId = baselineComponentIds["Encryption"]!"" ]

    [#-- Network Lookup --]
    [#local networkLink = getOccurrenceNetwork(occurrence).Link!{} ]
    [#local networkLinkTarget = getLinkTarget(occurrence, networkLink ) ]
    [#if ! networkLinkTarget?has_content ]
        [@fatal message="Network could not be found" context=networkLink /]
        [#return]
    [/#if]
    [#local networkConfiguration = networkLinkTarget.Configuration.Solution]
    [#local networkResources = networkLinkTarget.State.Resources ]
    [#local vpcId = networkResources["vpc"].Id ]

    [#local dnsPorts = [ 
        "dns-tcp", "dns-tcp",
        "globalcatalog",
        "kerebosauth88-tcp", "kerebosauth88-udp", "kerebosauth464-tcp", "kerebosauth464-udp",
        "ldap-tcp", "ldap-udp", "ldaps",
        "netlogin-tcp", "netlogin-udp", 
        "ntp",
        "rpc", "ephemeralrpctcp", "ephemeralrpcudp",
        "rsync",
        "smb-tcp", "smb-udp", 
        "anyicmp"
    ]]

    [#-- Resources and base configuration --]
    [#local dsId = resources["directory"].Id ]
    [#local fqdName = resources["directory"].Name ]
    [#local dsShortName = resources["directory"].ShortName ]
    [#local securityGroupId = resources["sg"].Id ]
    [#local securityGroupName = resources["sg"].Name ]

    [#local engine = solution.Engine]
    [#local enableSSO = solution["aws:EnableSSO"]]

    [#switch engine]
        [#case "ActiveDirectory"]
            [#local type = "MicrosoftAD"]
            [#local size = (solution.Size == "Standard")?then("Standard","Enterprise")]
            [#break]

        [#case "Simple"]
            [#local type = "SimpleAD"]
            [#local size = (solution.Size == "Small")?then("Small","Large")]
            [#break]

        [#default]
            [@precondition
                function="solution_directory"
                context=occurrence
                detail="Unsupported engine provided"
            /]
            [#local type = "unknown" ]
            [#local size = "unknown" ]

            [#break]
    [/#switch]

    [#local networkProfile = getNetworkProfile(occurrence)]

    [#local hibernate = solution.Hibernate.Enabled && isOccurrenceDeployed(occurrence)]

    [#-- Link Processing --]
    [#list solution.Links?values as link]
        [#if link?is_hash]
            [#local linkTarget = getLinkTarget(occurrence, link) ]

            [@debug message="Link Target" context=linkTarget enabled=false /]

            [#if !linkTarget?has_content]
                [#continue]
            [/#if]

            [#local linkTargetCore = linkTarget.Core ]
            [#local linkTargetConfiguration = linkTarget.Configuration ]
            [#local linkTargetResources = linkTarget.State.Resources ]
            [#local linkTargetAttributes = linkTarget.State.Attributes ]

            [#if deploymentSubsetRequired(DIRECTORY_COMPONENT_TYPE, true)]
                [@createSecurityGroupRulesFromLink
                    occurrence=occurrence
                    groupId=securityGroupId
                    linkTarget=linkTarget
                    inboundPorts=dnsPorts
                    networkProfile=networkProfile
                /]
            [/#if]

        [/#if]
    [/#list]

    [#-- Secret Management --]
    [#local secretStoreLink = getLinkTarget(occurrence, solution.RootCredentials.SecretStore) ]
    [#local passwordSecretKey = "password" ]

    [#if secretStoreLink?has_content ]
       [@setupComponentSecret
            occurrence=occurrence
            secretStoreLink=secretStoreLink
            kmsKeyId=cmkKeyId
            secretComponentResources=resources["rootCredentials"]
            secretComponentConfiguration=
                solution.RootCredentials.Secret + {
                    "Generated" : {
                        "Content" : { "username" : solution.RootCredentials.Username },
                        "SecretKey" : passwordSecretKey
                    }
                }
            componentType=DIRECTORY_COMPONENT_TYPE
        /]
    [#else]
        [@fatal
            message="Could not find link to secret store or link was invalid"
            detail="Add a link to a secret store component which will manage the root credentials"
            context=solution.RootCredentials.SecretStore
        /]
    [/#if]

    [#-- Output Generation --]
    [#if deploymentSubsetRequired(DIRECTORY_COMPONENT_TYPE, true)]

        [#-- Network Security --]
        [@createSecurityGroup
            id=securityGroupId
            name=securityGroupName
            vpcId=vpcId
            occurrence=occurrence
        /]

        [@createSecurityGroupRulesFromNetworkProfile
            occurrence=occurrence
            groupId=securityGroupId
            networkProfile=networkProfile
            inboundPorts=dnsPorts
        /]

        [#local ingressNetworkRule = {
                "Ports" : dnsPorts,
                "IPAddressGroups" : solution.IPAddressGroups
        }]

        [@createSecurityGroupIngressFromNetworkRule
            occurrence=occurrence
            groupId=securityGroupId
            networkRule=ingressNetworkRule
        /]

        [#if !hibernate]
            [#local vpcSettings= {
                    "SubnetIds" : getSubnets(core.Tier, networkResources),
                    "VpcId" : getReference(vpcId)
                }]

            [#-- Component Specific Resources --]
            [@createDSInstance
                id=dsId
                name=dsShortName
                type=type
                masterPassword=getSecretManagerSecretRef(resources["rootCredentials"]["secret"].Id, "password")
                enableSSO=enableSSO
                fqdName=fqdName
                shortName=shortName
                size=size
                vpcSettings=vpcSettings
            /]

            [@cfOutput
                formatId(dsId, IP_ADDRESS_ATTRIBUTE_TYPE), 
                {
                    "Fn::Join": [
                        ",",
                        {
                            "Fn::GetAtt": [
                                dsId,
                                "DnsIpAddresses"
                            ]
                        }
                    ]
                },
                false
            /]

[#--
            [@cfOutput
                formatId(dsId, ALIAS_ATTRIBUTE_TYPE), 
                {
                    "Fn::Join": [
                        ",",
                        {
                            "Fn::GetAtt": [
                                dsId,
                                "Alias"
                            ]
                        }
                    ]
                },
                false
            /]
--]

        [/#if]
    [/#if]

[/#macro]
