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

    [#-- Resources and base configuration --]
    [#local dsId = resources["directory"].Id ]
    [#local fqdName = resources["directory"].Name ]
    [#local dsShortName = resources["directory"].ShortName ]
    [#local dsUserName = resources["directory"].Username ]

    [#local securityGroupId = resources["sg"].Id ]
    [#local securityGroupName = resources["sg"].Name ]

    [#local engine = solution.Engine]
    [#local enableSSO = solution["aws:EnableSSO"]]

    [#switch engine]
        [#case "ActiveDirectory"]
            [#local type = "MicrosoftAD"]
            [#local size = (solution.Size == "Small")?then("Standard","Enterprise")]
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
                        "Content" : {
                            "username" : dsUserName
                        },
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
                dependencies=[
                    resources["rootCredentials"]["secret"].Id
                ]
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

    [#local epilogue_cidr=[]]
    [#local epilogue_content=[]]

    [#if ! solution.IPAddressGroups?seq_contains("_global")]
        [#local epilogue_content += [
                r'   info "SecGroupId = ${secgrp_id}"', 
                r'   aws --region ' + getRegion() + r' ec2 describe-security-group-rules --filter "Name=group-id, Values=${secgrp_id}" --query "SecurityGroupRules[?CidrIpv4==' + r"'0.0.0.0/0'" + r'].[IpProtocol, FromPort, ToPort, SecurityGroupRuleId]" --output text | ' + r"sed 's/\t/;/g'" + r' | while read line',
                r'   do',
                r"      IFS=';'" + r' read -r -a RuleSegment <<< "$line"'
            ]
        ]
        [#-- Loop over all IP addresses that are allowed --]
        [#list getGroupCIDRs(solution.IPAddressGroups, true, occurrence ) as cidr]
            [#local epilogue_content += [
                    '      info "cidr = ${cidr}"'
                ]
            ]
            [#local epilogue_content += [
                    r'      aws --region ' + getRegion() + r' ec2 authorize-security-group-ingress --group-id ${secgrp_id} --ip-permissions IpProtocol=${RuleSegment[0]},FromPort=${RuleSegment[1]},ToPort=${RuleSegment[2]},IpRanges=' + r"'[{CidrIp=" + cidr + r"}]'"
                ]
            ]
        [/#list]
        [#local epilogue_content += [
                r'      info "Removing Rule ${RuleSegment[3]}"',
                r'      aws --region ' + getRegion() + r' ec2 revoke-security-group-ingress --group-id ${secgrp_id} --security-group-rule-ids ${RuleSegment[3]}',
                r'   done'
            ]
        ]
    [/#if]

    [#if deploymentSubsetRequired("epilogue", false ) ]
        [@addToDefaultBashScriptOutput
            content=
            [
                r'case ${STACK_OPERATION} in',
                r'  create|update)',
                r'   ds_id="$(get_cloudformation_stack_output "' + getRegion() + r'" "${STACK_NAME}" "' + dsId + r'" "ref" || return $?)"',
                r'   ds_filter="Name=description,Values=AWS created security group for ${ds_id} directory controllers"',
                r'   secgrp_id="$(aws --region ' + getRegion() + r' ec2 describe-security-groups --filters "${ds_filter}" --query ' + r"'SecurityGroups[0].GroupId'" + r' --output text)" ',
                r'   info "SecurityGroupId=${secgrp_id}"'
            ] +
            epilogue_content +
            [
                r'   ;;',
                r'esac'
            ]
        /]
    [/#if]


[/#macro]
