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

    [#local engine = solution.Engine]
    [#local enableSSO = solution["aws:EnableSSO"]]

    [#local networkProfile = getNetworkProfile(occurrence)]
    [#local hibernate = solution.Hibernate.Enabled && isOccurrenceDeployed(occurrence)]

    [#local directory = {}]
    [#local sg = resources["sg"]]

    [#-- Resources and base configuration --]
    [#switch engine ]
        [#case "ActiveDirectory"]
        [#case "Simple"]
            [#local directory = resources["directory"]]
            [#break]

        [#case "aws:ADConnector" ]
            [#local directory = resources["connector"]]
            [#break]

        [#default]
            [@fatal
                message="Unsupported engine provided"
                context={
                    "Id" : core.RawId,
                    "Engine" : engine
                }
            /]
            [#return]
    [/#switch]

    [#-- Determine Sizing" --]
    [#switch engine]
        [#case "ActiveDirectory"]
            [#local type = "MicrosoftAD"]
            [#local size = (solution.Size == "Small")?then("Standard","Enterprise")]
            [#break]

        [#case "Simple"]
            [#local type = "SimpleAD"]
            [#local size = (solution.Size == "Small")?then("Small","Large")]
            [#break]

        [#case "aws:ADConnector"]
            [#local type = "ADConnector"]
            [#local size = solution.Size ]
            [#break]

        [#default]
            [#local type = "unknown" ]
            [#local size = "unknown" ]
            [#break]
    [/#switch]

    [#-- Secret Management --]
    [#local secretLink = getLinkTarget(occurrence, (solution.RootCredentials.Link)!{}) ]
    [#local passwordSecretKey = "password" ]
    [#local secretSource = solution.RootCredentials.Secret.Source ]
    [#local secretId = ""]

    [#if ! secretLink?has_content ]
       [@fatal
            message="Could not find link to secret store or link was invalid"
            detail="Add a link to a secret store component which will manage the root credentials"
            context=solution.RootCredentials.SecretStore
        /]
        [#return]
    [/#if]

    [#-- Validate Username --]
    [#switch solution.Engine ]
        [#case "Simple"]
        [#case "ActiveDirectory" ]
            [#if directory.Username == "root" ]
                [@warn
                    message="Root user used for older AD deployments"
                    detail="The username will be Admin instead of root"
                /]
            [#elseif ! directory.Username == "Admin" ]
                [@fatal
                    message="Invalid username for directory engine"
                    detail="Only the user name Admin is permitted"
                /]
            [/#if]
            [#break]
    [/#switch]

    [#switch secretSource ]
        [#case "generated" ]
            [#if ((secretLink.Core.Type)!"") == SECRETSTORE_COMPONENT_TYPE ]

                [#local secretId = resources["rootCredentials"]["secret"].Id ]

                [@setupComponentGeneratedSecret
                    occurrence=occurrence
                    secretStoreLink=secretLink
                    kmsKeyId=cmkKeyId
                    secretComponentResources=resources["rootCredentials"]
                    secretComponentConfiguration=
                        solution.RootCredentials.Secret + {
                            "Generated" : {
                                "Content" : {
                                    "username" : (directory.Username)!""
                                },
                                "SecretKey" : passwordSecretKey
                            }
                        }
                    componentType=DIRECTORY_COMPONENT_TYPE
                /]
            [#else]
                [@fatal
                    message="Link to secret must be a secret store for generated secrets"
                    detail="Configure a link to the secret store"
                    context={
                        "Component" : core.RawId,
                        "RootCredentialsLink" : solution.RootCredentials.Link
                    }
                /]
            [/#if]
            [#break]

        [#case "user"]
            [#if ((secretLink.Core.Type)!"") == SECRETSTORE_SECRET_COMPONENT_TYPE ]

                [#local secretId = secretLink.State.Resources["secret"].Id ]

            [#else]
                [@fatal
                    message="Link to secret must be a secret for user defined secrets"
                    detail="Configure a link to a secret store secret"
                    context={
                        "Component" : core.RawId,
                        "RootCredentialsLink" : solution.RootCredentials.Link,
                        "LinkComponentType" : secretLink.Core.Type
                    }
                /]
            [/#if]
            [#break]
    [/#switch]


    [#-- Output Generation --]
    [#if deploymentSubsetRequired(DIRECTORY_COMPONENT_TYPE, true)]

        [#switch engine ]
            [#case "ActiveDirectory"]
            [#case "Simple"]
                [#if !hibernate]

                    [#local directorySubnets = getSubnets(core.Tier, networkResources)]

                    [#local vpcSettings= {
                            "SubnetIds" : directorySubnets,
                            "VpcId" : getReference(vpcId)
                        }]

                    [#-- Component Specific Resources --]
                    [@createDSInstance
                        id=directory.Id
                        name=directory.ShortName
                        type=type
                        masterPassword=getSecretManagerSecretRef(secretId, "password")
                        enableSSO=enableSSO
                        fqdName=directory.Name
                        shortName=shortName
                        size=size
                        vpcSettings=vpcSettings
                        dependencies=[
                            secretId
                        ]
                    /]

                    [#if networkConfiguration.DNS.UseProvider ]

                        [#local resolverEndpointIPAddresses = getSubnets(core.Tier, networkResources)?map( x -> getResolverIPAddress(x)) ]

                        [#local resolverEndpoint = resources["resolver"]["endpoint"] ]
                        [#local resolverRule = resources["resolver"]["rule"]]
                        [#local resolverRuleAssoc = resources["resolver"]["association"]]
                        [#local resolverSecurityGroup = resources["resolver"]["sg"]]

                        [@createRoute53ResolverEndpoint
                            id=resolverEndpoint.Id
                            name=resolverEndpoint.Name
                            direction="OUTBOUND"
                            resolverIPAddresses=resolverEndpointIPAddresses
                            securityGroupIds=resolverSecurityGroup.Id
                            tags=getOccurrenceCoreTags(occurrence, resolverEndpoint.Name)
                        /]

                        [#local targetIps = []]

                        [#list directorySubnets as subnet]

                            [#local targetIps += [
                                getResolverRuleTargetIp(
                                    {
                                        "Fn::Select" : [
                                            subnet?index,
                                            {
                                                "Fn::GetAtt": [
                                                    directory.Id,
                                                    "DnsIpAddresses"
                                                ]
                                            }
                                        ]
                                    },
                                    ports["dns-udp"]
                                )]]
                        [/#list]

                        [@createRoute53ResolverRule
                            id=resolverRule.Id
                            name=resolverRule.Name
                            domainName=directory.Name
                            resolverEndpointId=resolverEndpoint.Id
                            ruleType="FORWARD"
                            tags=getOccurrenceCoreTags(occurrence, resolverRule.Name)
                            targetIps=targetIps
                        /]

                        [@createRoute53ResolverRuleAssociation
                            id=resolverRuleAssoc.Id
                            name=resolverRuleAssoc.Name
                            resolverRuleId=resolverRule.Id
                            vpcId=vpcId
                        /]

                        [@createSecurityGroup
                            id=resolverSecurityGroup.Id
                            name=resolverSecurityGroup.Name
                            vpcId=vpcId
                            description="Directory DNS Resolver integration with private network"
                            occurrence=occurrence
                        /]

                        [#list solution.Links?values as link]
                            [#if link?is_hash]
                                [#local linkTarget = getLinkTarget(occurrence, link) ]

                                [@debug message="Link Target" context=linkTarget enabled=false /]

                                [#if !linkTarget?has_content]
                                    [#continue]
                                [/#if]

                                [#if deploymentSubsetRequired("cache", true)]
                                    [@createSecurityGroupRulesFromLink
                                        occurrence=occurrence
                                        groupId=resolverSecurityGroup.Id
                                        linkTarget=linkTarget
                                        inboundPorts=[]
                                    /]
                                [/#if]

                            [/#if]
                        [/#list]

                        [@createSecurityGroupRulesFromNetworkProfile
                            occurrence=occurrence
                            groupId=resolverSecurityGroup.Id
                            networkProfile=networkProfile
                            inboundPorts=[]
                        /]
                    [/#if]

                [/#if]
                [#break]
        [/#switch]
    [/#if]


    [#if deploymentSubsetRequired("epilogue", false ) ]

        [#local directoryIdScript = []]

        [#switch engine ]
            [#case "ActiveDirectory"]
            [#case "Simple"]
                [#local directoryIdScript = [
                    r'case ${STACK_OPERATION} in',
                    r'  create|update)'
                    r'   ds_id="$(get_cloudformation_stack_output "' + getRegion() + r'" "${STACK_NAME}" "' + directory.Id + r'" "ref" || return $?)"'
                    r'   ;;',
                    r'esac'
                ]]
                [#break]

            [#case "aws:ADConnector" ]

                [#local adDNSIPs = solution["aws:engine:ADConnector"].ADIPAddresses]
                [#if ! (adDNSIPs)?has_content ]
                    [@fatal
                        message="No AD IP Addresses defined"
                        detail="Define IP Addresses for the AD Connector"
                        context={
                            "connectorId" : occurrence.Core.RawId,
                            "Configuration" : solution
                        }
                    /]
                [/#if]

                [#local directoryIdScript =
                                createADConnectorScript(
                                    directory.Id,
                                    "ds_id",
                                    getRegion(),
                                    secretId,
                                    size,
                                    vpcId,
                                    getSubnets(core.Tier, networkResources),
                                    directory.DomainName,
                                    (solution["aws:engine:ADConnector"].ADIPAddresses)![],
                                    getOccurrenceCoreTags(occurrence, core.FullName))]
                [#break]
        [/#switch]


        [#local secgrp_lockdown=[]]

        [#if ! solution.IPAddressGroups?seq_contains("_global")]

            [#local secgrp_lockdown += [
                    r'case ${STACK_OPERATION} in',
                    r'  create|update)'
                    r'   ds_filter="Name=description,Values=AWS created security group for ${ds_id} directory controllers"'
                    r'   secgrp_id="$(aws --region ' + getRegion() + r' ec2 describe-security-groups --filters "${ds_filter}" --query ' + r"'SecurityGroups[0].GroupId'" + r' --output text)" ',
                    r'   info "SecurityGroupId=${secgrp_id}"'
                ]
            ]

            [#local work_content = r'   cidr_set="' ]
            [#list getGroupCIDRs(solution.IPAddressGroups, true, occurrence ) as cidr]
                [#local work_content += ';'+cidr ]
            [/#list]
            [#local work_content += ';"' ]
            [#local secgrp_lockdown += [
                    r'   cidr_set="~$(aws --region ' + getRegion() + r' ec2 describe-security-group-rules --filter "Name=group-id, Values=${secgrp_id}" --query "SecurityGroupRules[?CidrIpv4!=' + r"''" + r'].[CidrIpv4]" --output text | ' + r"grep -v 'None'" + r' | sort -u )~"',
                    r'   cidr_set="$(echo ${cidr_set} | sed ' + r"'s/ /~/g'" + r')"',
                    r'   info "cidr_set = ${cidr_set}"',
                    r'   aws --region ' + getRegion() + r' ec2 describe-security-group-rules --filter "Name=group-id, Values=${secgrp_id}" --query "SecurityGroupRules[?CidrIpv4!=' + r"''" + r'].[IpProtocol, FromPort, ToPort]" --output text | ' + r"sed 's/\t/;/g'" + r' | sort -u | while read line',
                    r'   do',
                    r"      IFS=';'" + r' read -r -a RuleSegment <<< "$line"'
                ]
            ]
            [#-- Loop over all IP addresses that are allowed --]
            [#local removal_filter = '?']
            [#list getGroupCIDRs(solution.IPAddressGroups, true, occurrence ) as cidr]
                [#local secgrp_lockdown += [
                        '      info "cidr = ${cidr}"'
                    ]
                ]
                [#local removal_filter += r'CidrIpv4!=' + "'${cidr}' && "]
                [#local secgrp_lockdown += [
                        r'      if [ -n "$(echo $cidr_set | sed -e "s;.*~' + cidr + r'~.*;;")" ] ; then',
                        r'          aws --region ' + getRegion() + r' ec2 authorize-security-group-ingress --group-id ${secgrp_id} --ip-permissions IpProtocol=${RuleSegment[0]},FromPort=${RuleSegment[1]},ToPort=${RuleSegment[2]},IpRanges=' + r"'[{CidrIp=" + cidr + r"}]'",
                        r'      fi'
                    ]
                ]
            [/#list]
            [#local removal_filter += "! IsEgress"]

            [#local secgrp_lockdown += [
                    r'   done'
                    r'   aws --region ' + getRegion() + r' ec2 describe-security-group-rules --filter "Name=group-id, Values=${secgrp_id}" --query "SecurityGroupRules[' + removal_filter + r'].[IpProtocol, FromPort, ToPort, SecurityGroupRuleId]" --output text | ' + r"sed 's/\t/;/g'" + r' | while read line',
                    r'   do',
                    r"      IFS=';'" + r' read -r -a RuleSegment <<< "$line"'
                ]
            ]
            [#local secgrp_lockdown += [
                    r'      info "Removing Rule ${RuleSegment[3]}"',
                    r'      aws --region ' + getRegion() + r' ec2 revoke-security-group-ingress --group-id ${secgrp_id} --security-group-rule-ids ${RuleSegment[3]}',
                    r'   done',
                    r'   ;;',
                    r'esac'
                ]
            ]

        [/#if]

        [@addToDefaultBashScriptOutput
            content=
                directoryIdScript +
                secgrp_lockdown
        /]
    [/#if]
[/#macro]
