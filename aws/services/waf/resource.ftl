[#ftl]

[#-- Regional resource types replicate global ones --]
[#function formatWAFResourceType baseResourceType regional ]
    [#return "AWS::" + regional?then("WAFRegional::","WAF::") + baseResourceType ]
[/#function]

[#-- Capture similarity between conditions --]
[#macro createWAFCondition id name type filters=[] valueSet={} regional=false]
    [#if (WAFConditions[type].ResourceType)?has_content]
        [#local result = [] ]
        [#list asArray(filters) as filter]
            [#switch type]
                [#case AWS_WAF_BYTE_MATCH_CONDITION_TYPE]
                    [#local result += formatWAFByteMatchTuples(filter, valueSet) ]
                    [#break]
                [#case AWS_WAF_GEO_MATCH_CONDITION_TYPE]
                    [#local result += formatWAFGeoMatchTuples(filter, valueSet) ]
                    [#break]
                [#case AWS_WAF_IP_MATCH_CONDITION_TYPE]
                    [#local result += formatWAFIPMatchTuples(filter, valueSet) ]
                    [#break]
                [#case AWS_WAF_SIZE_CONSTRAINT_CONDITION_TYPE]
                    [#local result += formatWAFSizeConstraintTuples(filter, valueSet) ]
                    [#break]
                [#case AWS_WAF_SQL_INJECTION_MATCH_CONDITION_TYPE]
                    [#local result += formatWAFSqlInjectionMatchTuples(filter, valueSet) ]
                    [#break]
                [#case AWS_WAF_XSS_MATCH_CONDITION_TYPE]
                    [#local result += formatWAFXssMatchTuples(filter, valueSet) ]
                    [#break]
            [/#switch]
        [/#list]

        [@cfResource
            id=id
            type=formatWAFResourceType(WAFConditions[type].ResourceType, regional)
            properties=
                    {
                        "Name": name
                    } +
                    contentIfContent(
                        attributeIfContent(
                            WAFConditions[type].TuplesAttributeKey!"",
                            result
                        ),
                        result
                    )
        /]
    [/#if]
[/#macro]

[#macro createWAFByteMatchSetCondition id name matches=[] valueSet={} regional=false]
    [@createWAFCondition
        id=id
        name=name
        type=AWS_WAF_BYTE_MATCH_CONDITION_TYPE
        filters=matches
        valueSet=valueSet
        regional=regional /]
[/#macro]

[#macro createWAFGeoMatchSetCondition id name countryCodes=[] regional=true]
    [#local filters = [{"Targets" : "countrycodes"}] ]
    [#local valueSet = {"countrycodes" : asFlattenedArray(countryCodes) } ]
    [@createWAFCondition
        id=id
        name=name
        type=AWS_WAF_GEO_MATCH_CONDITION_TYPE
        filters=filters
        valueSet=valueSet
        regional=regional /]
[/#macro]

[#macro createWAFIPSetCondition id name cidr=[] regional=false]
    [#local filters = [{"Targets" : "ips"}] ]
    [#local valueSet = {"ips" : asFlattenedArray(cidr) } ]
    [@createWAFCondition
        id=id
        name=name
        type=AWS_WAF_IP_MATCH_CONDITION_TYPE
        filters=filters
        valueSet=valueSet
        regional=regional /]
[/#macro]

[#macro createWAFSizeConstraintCondition id name constraints=[] valueSet={} regional=false]
    [@createWAFCondition
        id=id
        name=name
        type=AWS_WAF_SIZE_CONSTRAINT_CONDITION_TYPE
        filters=constraints
        valueSet=valueSet
        regional=regional /]
[/#macro]

[#macro createWAFSqlInjectionMatchSetCondition id name matches=[] valueSet={} regional=false]
    [@createWAFCondition
        id=id
        name=name
        type=AWS_WAF_SQL_INJECTION_MATCH_CONDITION_TYPE
        filters=matches
        valueSet=valueSet
        regional=regional /]
[/#macro]

[#macro createWAFXssMatchSetCondition id name matches=[] valueSet={} regional=false]
    [@createWAFCondition
        id=id
        name=name
        type=AWS_WAF_XSS_MATCH_CONDITION_TYPE
        filters=matches
        valueSet=valueSet
        regional=regional /]
[/#macro]

[#macro createWAFRule id name metric conditions=[] valueSet={} regional=false rateKey="" rateLimit=""]
    [#local predicates = [] ]
    [#list asArray(conditions) as condition]
        [#local rateBased = (rateKey?has_content && rateLimit?has_content)]
        [#local conditionId = condition.Id!""]
        [#local conditionName = condition.Name!conditionId]
        [#-- Generate id/name from rule equivalents if not provided --]
        [#if !conditionId?has_content]
            [#local conditionId = formatDependentWAFConditionId(condition.Type, id, "c" + condition?counter?c)]
        [/#if]
        [#if !conditionName?has_content]
            [#local conditionName = formatName(name,"c" + condition?counter?c,condition.Type)]
        [/#if]
        [#if condition.Filters?has_content]
            [#-- Condition to be created with the rule --]
            [@createWAFCondition
                id=conditionId
                name=conditionName
                type=condition.Type
                filters=condition.Filters
                valueSet=valueSet
                regional=regional /]
        [/#if]
        [#local predicates +=
            [
                {
                    "DataId" : getReference(AWS_PROVIDER, conditionId),
                    "Negated" : (condition.Negated)!false,
                    "Type" : rateBased?then("IPMatch", condition.Type)
                }
            ]
        ]
    [/#list]

    [@cfResource
        id=id
        type=formatWAFResourceType(rateBased?then("RateBasedRule", "Rule"), regional)
        properties=
            {
                "MetricName" : metric?replace("-","X"),
                "Name": name
            } +
            attributeIfTrue("MatchPredicates", rateBased, predicates) +
            attributeIfTrue("Predicates", (!rateBased), predicates) +
            attributeIfContent("RateKey", rateKey) +
            attributeIfContent("RateLimit", rateLimit)
    /]
[/#macro]

[#-- Rules are grouped into bands. Bands are sorted into ascending alphabetic --]
[#-- order, with rules within a band ordered based on occurrence in the rules --]
[#-- array. Rules without a band are put into the default band.               --]
[#macro createWAFAcl id name metric defaultAction rules=[] valueSet={} regional=false bandDefault="default" ]
    [#-- Determine the bands --]
    [#local bands = [] ]
    [#list asArray(rules) as rule]
        [#local bands += [rule.Band!bandDefault] ]
    [/#list]
    [#local bands = getUniqueArrayElements(bands)?sort]

    [#-- Priorities based on band order --]
    [#local aclRules = [] ]
    [#local nextRulePriority = 1]
    [#list bands as band]
        [#list asArray(rules) as rule]
            [#local ruleBand = rule.Band!bandDefault]
            [#if ruleBand != band]
                [#continue]
            [/#if]
            [#local ruleId = rule.Id!""]
            [#local ruleName = rule.Name!ruleId]
            [#local ruleMetric = rule.Metric!ruleName]
            [#-- Rule to be created with the acl --]
            [#-- Generate id/name/metric from acl equivalents if not provided --]
            [#if !ruleId?has_content]
                [#local ruleId = formatDependentWAFRuleId(id,"r" + rule?counter?c)]
            [/#if]
            [#if !ruleName?has_content]
                [#local ruleName = formatName(name,"r" + rule?counter?c,rule.NameSuffix!"")]
            [/#if]
            [#if !ruleMetric?has_content]
                [#local ruleMetric = formatId(metric,"r" + rule?counter?c)]
            [/#if]
            [#if rule.Conditions?has_content]
                [@createWAFRule
                    id=ruleId
                    name=ruleName
                    metric=ruleMetric
                    conditions=rule.Conditions
                    valueSet=valueSet
                    regional=regional
                    rateKey=rule.RateKey!""
                    rateLimit=rule.RateLimit!"" /]
            [/#if]
            [#local aclRules +=
                [
                    {
                        "RuleId" : getReference(AWS_PROVIDER, ruleId),
                        "Priority" : nextRulePriority,
                        "Action" : {
                        "Type" : rule.Action
                        }
                    }
                ]
            ]
            [#local nextRulePriority += 1]
        [/#list]
    [/#list]

    [@cfResource
        id=id
        type=formatWAFResourceType("WebACL", regional)
        properties=
            {
                "DefaultAction" : {
                    "Type" : defaultAction
                },
                "MetricName" : metric?replace("-","X"),
                "Name": name,
                "Rules" : aclRules
            }
    /]
[/#macro]

[#macro createWAFAclFromSecurityProfile id name metric wafSolution securityProfile occurrence={} regional=false]
    [#if wafSolution.OWASP]
        [#local wafProfile = wafProfiles[securityProfile.WAFProfile!""]!{} ]
    [#else]
        [#local wafProfile = {"Rules" : [], "DefaultAction" : "ALLOW"} ]
    [/#if]
    [#local wafValueSet = wafValueSets[securityProfile.WAFValueSet!""]!{} ]

    [#if getGroupCIDRs(wafSolution.IPAddressGroups, true, occurrence, true) ]
        [#local wafValueSet += {
                "whitelistedips" : getGroupCIDRs(wafSolution.IPAddressGroups, true, occurrence)
            } ]
        [#local wafProfile += {
                "Rules" :
                    wafProfile.Rules +
                    [
                        {
                        "Rule" : "whitelistips",
                        "Action" : "ALLOW"
                        }
                    ],
                "DefaultAction" : "BLOCK"
            } ]
    [/#if]

    [#local whitelistedCountryCodes = getGroupCountryCodes(wafSolution.CountryGroups, false) ]
    [#if whitelistedCountryCodes?has_content]
        [#local wafValueSet += {
                "whitelistedcountrycodes" : whitelistedCountryCodes
            } ]
        [#local wafProfile += {
                "Rules" :
                    wafProfile.Rules +
                    [
                        {
                        "Rule" : "whitelistcountries",
                        "Action" : "ALLOW"
                        }
                    ],
                "DefaultAction" : "BLOCK"
            } ]
    [/#if]

    [#local blacklistedCountryCodes = getGroupCountryCodes(wafSolution.CountryGroups, true) ]
    [#if blacklistedCountryCodes?has_content]
        [#local wafValueSet += {
                "blacklistedcountrycodes" : blacklistedCountryCodes
            } ]
        [#local wafProfile += {
                "Rules" :
                    wafProfile.Rules +
                    [
                        {
                        "Rule" : "blacklistcountries",
                        "Action" : "BLOCK"
                        }
                    ],
                "DefaultAction" : "ALLOW"
            } ]
    [/#if]
    [#local rules = getWAFProfileRules(wafProfile, wafRuleGroups, wafRules, wafConditions)]

    [#if wafSolution.RateLimits?has_content]

        [#-- IP-based rate-limiting --]
        [#if wafSolution.RateLimits.IP?has_content]
            [#list wafSolution.RateLimits as id,rateConfig]
                [#local wafValueSet += { id : getGroupCIDRs(rateConfig.IPAddressGroups, true, occurrence) }]
                [#local rules = combineEntities(
                    rules,
                    [
                        {
                            "Name" : id,
                            "RateKey" : "IP",
                            "RateLimit" : rateConfig.Limit,
                            "Conditions" : [
                                {
                                    "Type" : "IPMatch",
                                    "Filters" : [ { "Targets" : [ id ] }],
                                    "Negated" : false
                                }
                            ],
                            "Action" : "BLOCK"
                        }
                    ],
                    ADD_COMBINE_BEHAVIOUR
                )]

            [/#list]
        [/#if]
    [/#if]

    [@createWAFAcl
        id=id
        name=name
        metric=metric
        defaultAction=wafProfile.DefaultAction
        rules=rules
        valueSet=wafValueSet
        regional=regional
        bandDefault=wafProfile.BandDefault!"default" /]
[/#macro]

[#-- Associations are only relevant for regional endpoints --]
[#macro createWAFAclAssociation id wafaclId endpointId dependencies=[] ]
    [@cfResource
        id=id
        type=formatWAFResourceType("WebACLAssociation", true)
        properties=
            {
                "ResourceArn" : getArn(endpointId),
                "WebACLId" : getReference(AWS_PROVIDER, wafaclId)
            }
        dependencies=dependencies
    /]
[/#macro]


[#macro enableWAFLogging wafaclId deliveryStreamId="" regional=false ]

    [#if regional ]
        [#local wafType = "regional" ]
    [#else]
        [#local wafType = "global" ]
    [/#if]

    [#if deliveryStreamId?has_content ]
        [#if deploymentSubsetRequired("epilogue", false) ]
            [@addToDefaultBashScriptOutput
                content=[
                    r' case ${STACK_OPERATION} in',
                    r'   create|update)',
                    r'       manage_waf_logging ' +
                    r'          "' + region + r'"' +
                    r'          "' + wafaclId + r'"' +
                    r'          "' + wafType + r'"' +
                    r'          "enable"' +
                    r'          "' + deliveryStreamId + r'"' +
                    r'          || return $?',
                    r'       ;;',
                    r'    delete)',
                    r'       manage_waf_logging ' +
                    r'          "' + region + r'"' +
                    r'          "' + wafaclId + r'"' +
                    r'          "' + wafType + r'"' +
                    r'          "disable"' +
                    r'          || return $?',
                    r' esac'
                ]
            /]
        [/#if]
    [#else]
        [#if deploymentSubsetRequired("epilogue", false) ]
            [@addToDefaultBashScriptOutput
                content=[
                    r' case ${STACK_OPERATION} in',
                    r'    create|update|delete)',
                    r'       manage_waf_logging ' +
                    r'          "' + region + r'"' +
                    r'          "' + wafaclId + r'"' +
                    r'          "' + wafType + r'"' +
                    r'          "disable"' +
                    r'          || return $?',
                    r' esac'
                ]
            /]
        [/#if]
    [/#if]
[/#macro]
