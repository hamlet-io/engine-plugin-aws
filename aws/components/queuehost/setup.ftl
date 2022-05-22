[#ftl]
[#macro aws_queuehost_cf_deployment_generationcontract occurrence ]
    [@addDefaultGenerationContract subsets=[ "template", "epilogue" ] /]
[/#macro]

[#macro aws_queuehost_cf_deployment occurrence ]
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
    [#local brokerId = resources["broker"].Id ]
    [#local brokerFullName = resources["broker"].Name ]
    [#local brokerShortName = resources["broker"].ShortName ]
    [#local brokerPorts = resources["broker"].Ports]
    [#local securityGroupId = resources["sg"].Id ]
    [#local securityGroupName = resources["sg"].Name ]

    [#local engine = solution.Engine]
    [#local engineVersion = solution.EngineVersion ]

    [#local multiAZ = solution.MultiAZ]

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

            [#if deploymentSubsetRequired(QUEUEHOST_COMPONENT_TYPE, true)]
                [@createSecurityGroupRulesFromLink
                    occurrence=occurrence
                    groupId=securityGroupId
                    linkTarget=linkTarget
                    inboundPorts=[ port ]
                /]
            [/#if]

        [/#if]
    [/#list]

    [#-- Secret Management --]
    [#local secretStoreLink = getLinkTarget(occurrence, solution.RootCredentials.SecretStore) ]
    [#local passwordSecretKey = "password" ]

    [#if secretStoreLink?has_content ]

        [@setupComponentGeneratedSecret
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
            componentType=QUEUEHOST_COMPONENT_TYPE
        /]
    [#else]
        [@fatal
            message="Could not find link to secret store or link was invalid"
            detail="Added a link to a secret store component which will manage the root credentials"
            context=solution.RootCredentials.SecretStore
        /]
    [/#if]

    [#-- Output Generation --]
    [#if deploymentSubsetRequired(QUEUEHOST_COMPONENT_TYPE, true)]

        [#-- Network Security --]
        [@createSecurityGroup
            id=securityGroupId
            name=securityGroupName
            vpcId=vpcId
            tags=getOccurrenceTags(occurrence)
        /]

        [@createSecurityGroupRulesFromNetworkProfile
            occurrence=occurrence
            groupId=securityGroupId
            networkProfile=networkProfile
            inboundPorts=brokerPorts
        /]

        [#local ingressNetworkRule = {
                "Ports" : brokerPorts,
                "IPAddressGroups" : solution.IPAddressGroups
        }]

        [@createSecurityGroupIngressFromNetworkRule
            occurrence=occurrence
            groupId=securityGroupId
            networkRule=ingressNetworkRule
        /]


        [#if !hibernate]

            [#if ! testMaintenanceWindow(solution.MaintenanceWindow)]
                [@fatal message="Maintenance window incorrectly configured" context=solution /]
                [#return]
            [/#if]

            [#-- Monitoring and Alerts --]
            [#list (solution.Alerts?values)?filter(x -> x.Enabled) as alert ]

                [#local monitoredResources = getCWMonitoredResources(core.Id, resources, alert.Resource)]
                [#list monitoredResources as name,monitoredResource ]

                    [@debug message="Monitored resource" context=monitoredResource enabled=false /]

                    [#switch alert.Comparison ]
                        [#case "Threshold" ]
                            [@createAlarm
                                id=formatDependentAlarmId(monitoredResource.Id, alert.Id )
                                severity=alert.Severity
                                resourceName=core.FullName
                                alertName=alert.Name
                                actions=getCWAlertActions(occurrence, solution.Profiles.Alert, alert.Severity )
                                metric=getCWMetricName(alert.Metric, monitoredResource.Type, core.ShortFullName)
                                namespace=getCWResourceMetricNamespace(monitoredResource.Type, alert.Namespace)
                                description=alert.Description!alert.Name
                                threshold=alert.Threshold
                                statistic=alert.Statistic
                                evaluationPeriods=alert.Periods
                                period=alert.Time
                                operator=alert.Operator
                                reportOK=alert.ReportOk
                                unit=alert.Unit
                                missingData=alert.MissingData
                                dimensions=getCWResourceMetricDimensions(monitoredResource, resources)
                            /]
                        [#break]
                    [/#switch]
                [/#list]
            [/#list]

            [#-- Component Specific Resources --]
            [@createAmazonMqBroker
                id=brokerId
                name=brokerShortName
                engineType=engine
                engineVersion=engineVersion
                instanceType=solution.Processor.Type
                multiAz=multiAZ
                encrypted=solution.Encrypted
                kmsKeyId=cmkKeyId
                subnets=getSubnets(core.Tier, networkResources )
                securityGroupId=securityGroupId
                tags=getOccurrenceTags(occurrence)
                users=[
                    getAmazonMqUser(
                        getSecretManagerSecretRef(resources["rootCredentials"]["secret"].Id, "username"),
                        getSecretManagerSecretRef(resources["rootCredentials"]["secret"].Id, "password")
                    )
                ]
                autoMinorVersionUpdate=solution.AutoMinorUpgrade
                logging=true
                maintenanceWindow=
                    solution.MaintenanceWindow.Configured?then(
                        getAmazonMqMaintenanceWindow(
                            solution.MaintenanceWindow.DayOfTheWeek,
                            solution.MaintenanceWindow.TimeOfDay,
                            solution.MaintenanceWindow.TimeZone
                        ),
                        {}
                    )
            /]

        [/#if]
    [/#if]

    [#-- Create credentials embeded Url --]
    [#if deploymentSubsetRequired("epilogue", false) ]
        [@addToDefaultBashScriptOutput
            content=
            [
                r'case ${STACK_OPERATION} in',
                r'  create|update)',
                r'    info "Generating Encrypted Url"',
                r'    secret_arn="$(get_cloudformation_stack_output "' + getRegion() + r'" ' + r' "${STACK_NAME}" ' + resources["rootCredentials"]["secret"].Id + r' "ref" || return $?)"',
                r'    amqp_endopoint="$(get_cloudformation_stack_output "' + getRegion() + r'" ' + r' "${STACK_NAME}" ' + brokerId + r' "dns" || return $?)"',
                r'    secret_content="$(aws --region "' + getRegion() + r'" --output text secretsmanager get-secret-value --secret-id "${secret_arn}" --query "SecretString" || return $?)"',
                r'    username="' + solution.RootCredentials.Username + r'"',
                r'    password="$( echo "${secret_content}" | jq -r ".' + passwordSecretKey + r'")"',
                r'    url="${amqp_endopoint/"amqps://"/"amqps://${username}:${password}@"}"',
                r'    kms_encrypted_url="$(encrypt_kms_string "' + getRegion() + r'" ' + r' "${url}" ' + r' "' + getExistingReference(cmkKeyId, ARN_ATTRIBUTE_TYPE) + r'" || return $?)"'
            ] +
            pseudoStackOutputScript(
                "KMS Encrypted Url",
                {
                    formatId(brokerId, URL_ATTRIBUTE_TYPE) : r'${kms_encrypted_url}'
                },
                secretId
            ) +
            [
                "esac"
            ]
        /]
    [/#if]
[/#macro]
