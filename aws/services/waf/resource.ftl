[#ftl]

[#-- Regional resource types replicate global ones --]
[#function formatWAFResourceType baseResourceType regional version="v1" ]
    [#return "AWS::" + (version == "v2")?then("WAFv2::",regional?then("WAFRegional::","WAF::")) + baseResourceType ]
[/#function]

[#function formatV2TextTransformations textTransformations valueSet={}]
    [#local retVal=[]]
    [#list getWAFValueList(textTransformations, valueSet) as transform]
        [#local retVal += [ {
                "Priority": transform?counter,
                "Type": transform
            } ]]
    [/#list]
    [#return retVal]
[/#function]

[#function formatV2FieldMatch field]
    [#local retVal={}]
    [#switch (field.Type)!"Unknown"]
        [#case "QUERY_STRING"]
            [#local retVal += {
                "QueryString": {}
            }]
        [#break]
        [#case "URI"]
            [#local retVal += {
                "UriPath": {}
            }]
        [#break]
        [#case "BODY"]
            [#local retVal += {
                "JsonBody": {
                    "InvalidFallbackBehavior" : "EVALUATE_AS_STRING",
                    "MatchPattern" : {
                        "All" : {}
                    },
                    "MatchScope" : "ALL"
                }
            }]
        [#break]
        [#case "HEADER"]
            [#local retVal += {
                "SingleHeader": {
                    "Name": field.Data
                }
            }]
        [#break]
        [#default]
            [#local retVal += {
                "UnknownField": field
            }]
        [#break]
    [/#switch]
    [#return retVal]
[/#function]

[#function formatV2Conditions conditions valueSet={}]
    [#local v2Statements = []]
    [#list conditions as condition]
        [#local v2WkStatement = []]
        [#list condition.Filters as filter]
            [#switch condition.Type]
                [#case "SqlInjectionMatch"]
                    [#list getWAFValueList(filter.FieldsToMatch, valueSet) as field]
                        [#local v2WkStatement += [ {"SqliMatchStatement": {
                            "FieldToMatch": formatV2FieldMatch(field),
                            "TextTransformations": formatV2TextTransformations(filter.Transformations)
                            }}]]
                    [/#list]
                [#break]
                [#case "XssMatch"]
                    [#list getWAFValueList(filter.FieldsToMatch, valueSet) as field]
                    [#local v2WkStatement += [ { "XssMatchStatement": {
                        "FieldToMatch": formatV2FieldMatch(field),
                        "TextTransformations": formatV2TextTransformations(filter.Transformations)
                        }}]]
                    [/#list]
                [#break]
                [#case "ByteMatch"]
                    [#list getWAFValueList(filter.FieldsToMatch, valueSet) as field]
                        [#list getWAFValueList(filter.Constraints, valueSet) as constraint]
                            [#list getWAFValueList(filter.Targets, valueSet) as target]
                                [#local v2WkStatement += [ {"ByteMatchStatement": {
                                    "FieldToMatch": formatV2FieldMatch(field),
                                    "PositionalConstraint" : constraint,
                                    "SearchString" : target,
                                    "TextTransformations": formatV2TextTransformations(filter.Transformations)
                                    }}]]
                            [/#list]
                        [/#list]
                    [/#list]
                [#break]
                [#case "SizeConstraint"]
                    [#list getWAFValueList(filter.FieldsToMatch, valueSet) as field]
                        [#list getWAFValueList(filter.Operators, valueSet) as operator]
                            [#list getWAFValueList(filter.Sizes, valueSet) as size]
                                [#local v2WkStatement += [ { "SizeConstraintStatement": {
                                    "ComparisonOperator": operator,
                                    "FieldToMatch": formatV2FieldMatch(field),
                                    "TextTransformations": formatV2TextTransformations(filter.Transformations),
                                    "Size": size
                                    }}]]
                            [/#list]
                        [/#list]
                    [/#list]
                [#break]
                [#default]
                    [#local v2WkStatement += [ { "UnknownStatement": condition } ]]
                [#break]
            [/#switch]
        [/#list]

        [#if v2WkStatement?size > 1]
            [#local v2WkStatement = [ {"OrStatement": { "Statements": v2WkStatement}}]]
        [/#if]
        [#if condition.Negated]
            [#local v2Statements += [ { "NotStatement": v2WkStatement[0] }] ]
        [#else]
            [#local v2Statements += v2WkStatement]
        [/#if]
    [/#list]
    [#if v2WkStatement?size > 1]
        [#local v2Statements = { "AndStatement": { "Statements": v2Statements}}]
    [#else]
        [#local v2Statements = v2Statements[0] ]
    [/#if]
    [#return v2Statements]
[/#function]

[#-- Capture similarity between conditions --]
[#macro createWAFCondition id name type filters=[] valueSet={} regional=false version="v1"]
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
                    [#local result += formatWAFIPMatchTuples(filter, valueSet, version) ]
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
            type=formatWAFResourceType(WAFConditions[type].ResourceType, regional, version)
            properties=
                    {
                        "Name": name
                    } +
                    (version == "v2")?then(
                        { "Scope" : regional?then("REGIONAL","CLOUDFRONT")},
                        {}
                    )+
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

[#macro createWAFByteMatchSetCondition id name matches=[] valueSet={} regional=false version="v1" ]
    [@createWAFCondition
        id=id
        name=name
        type=AWS_WAF_BYTE_MATCH_CONDITION_TYPE
        filters=matches
        valueSet=valueSet
        regional=regional
        version=version /]
[/#macro]

[#macro createWAFGeoMatchSetCondition id name countryCodes=[] regional=true version="v1"]
    [#local filters = [{"Targets" : "countrycodes"}] ]
    [#local valueSet = {"countrycodes" : asFlattenedArray(countryCodes) } ]
    [@createWAFCondition
        id=id
        name=name
        type=AWS_WAF_GEO_MATCH_CONDITION_TYPE
        filters=filters
        valueSet=valueSet
        regional=regional
        version=version /]
[/#macro]

[#macro createWAFIPSetCondition id name cidr=[] regional=false version="v1" ]
    [#local filters = [{"Targets" : "ips"}] ]
    [#local valueSet = {"ips" : asFlattenedArray(cidr) } ]
    [#switch version]
        [#case "v1"]
            [@createWAFCondition
                id=id
                name=name
                type=AWS_WAF_IP_MATCH_CONDITION_TYPE
                filters=filters
                valueSet=valueSet
                regional=regional /]
        [#break]
        [#case "v2"]
            [@cfResource
                id=id
                type="AWS::WAFv2::IPSet"
                properties=
                        {
                            "Name": name,
                            "Addresses": formatWAFIPMatchTuples(filter, valueSet, version),
                            "IPAddressVersion": "IPV4",
                            "Scope": regional?then("REGIONAL","CLOUDFRONT")
                        }
            /]
        [#break]
    [/#switch]
[/#macro]

[#macro createWAFSizeConstraintCondition id name constraints=[] valueSet={} regional=false version="v1"]
    [@createWAFCondition
        id=id
        name=name
        type=AWS_WAF_SIZE_CONSTRAINT_CONDITION_TYPE
        filters=constraints
        valueSet=valueSet
        regional=regional
        version=version /]
[/#macro]

[#macro createWAFSqlInjectionMatchSetCondition id name matches=[] valueSet={} regional=false version="v1"]
    [@createWAFCondition
        id=id
        name=name
        type=AWS_WAF_SQL_INJECTION_MATCH_CONDITION_TYPE
        filters=matches
        valueSet=valueSet
        regional=regional
        version=version /]
[/#macro]

[#macro createWAFXssMatchSetCondition id name matches=[] valueSet={} regional=false version="v1"]
    [@createWAFCondition
        id=id
        name=name
        type=AWS_WAF_XSS_MATCH_CONDITION_TYPE
        filters=matches
        valueSet=valueSet
        regional=regional
        version=version /]
[/#macro]

[#macro createWAFRule id name metric conditions=[] valueSet={} regional=false rateKey="" rateLimit="" version="v1"]
    [#if version == "v2"]
        [#-- V2 templates create rules as part of WebAcl --]
        [#return]
    [/#if]

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
                regional=regional
                version=version /]
        [/#if]
        [#local predicates +=
            [
                {
                    "DataId" : getReference(conditionId),
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
[#macro createWAFAcl id name metric defaultAction rules=[] valueSet={} regional=false bandDefault="default" version="v1" ]
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
                    rateLimit=rule.RateLimit!""
                    version=version /]
            [/#if]
            [#switch version]
                [#case "v1"]
                    [#local aclRules +=
                        [
                            {
                                "RuleId" : getReference(ruleId),
                                "Priority" : nextRulePriority,
                                "Action" : {
                                    "Type" : rule.Action
                                }
                            }
                        ]
                    ]
                [#break]

                [#case "v2"]
                    [#local v2Action = (rule.Action)?lower_case?cap_first]
                    [#local v2Statement = formatV2Conditions(rule.Conditions, valueSet) ]
                    [#local aclRules +=
                        [
                            {
                                "Action" : {
                                    v2Action : {}
                                },
                                "Name" : ruleName,
                                "Priority" : nextRulePriority,
                                "Statement" : v2Statement,
                                "VisibilityConfig" : {
                                    "CloudWatchMetricsEnabled" : true,
                                    "MetricName" : ruleMetric,
                                    "SampledRequestsEnabled" : true
                                }
                            }
                        ]
                    ]
                [#break]
            [/#switch]
            [#local nextRulePriority += 1]
        [/#list]
    [/#list]

    [#local properties={}]
    [#switch version]
        [#case "v1"]
            [#local properties=
                {
                    "DefaultAction" : {
                        "Type" : defaultAction
                    },
                    "MetricName" : metric?replace("-","X"),
                    "Name": name,
                    "Rules" : aclRules
                }
            ]
        [#break]

        [#case "v2"]
            [#local defAction = defaultAction?lower_case?cap_first ]
            [#local properties=
                {
                    "DefaultAction" : {
                        defAction: {}
                    },
                    "Name": name,
                    "Rules" : aclRules,
                    "Scope": regional?then("REGIONAL","CLOUDFRONT"),
                    "VisibilityConfig" : {
                        "CloudWatchMetricsEnabled" : true,
                        "MetricName" : metric?replace("-","X"),
                        "SampledRequestsEnabled" : true
                    }
                }
            ]
        [#break]
    [/#switch]

    [@cfResource
        id=id
        type=formatWAFResourceType("WebACL", regional, version)
        properties=properties
    /]
[/#macro]

[#macro createWAFAclFromSecurityProfile id name metric wafSolution securityProfile occurrence={} regional=false version="v1"]
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
                        "Action" : (version == "v1")?then("ALLOW","Allow")
                        }
                    ],
                "DefaultAction" : (version == "v1")?then("BLOCK","Block")
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
                        "Action" : (version == "v1")?then("ALLOW","Allow")
                        }
                    ],
                "DefaultAction" : (version == "v1")?then("BLOCK","Block")
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
                        "Action" : (version == "v1")?then("BLOCK","Block")
                        }
                    ],
                "DefaultAction" : (version == "v1")?then("ALLOW","Allow")
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
                            "Action" : (version == "v1")?then("BLOCK","Block")
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
        bandDefault=wafProfile.BandDefault!"default"
        version=version /]
[/#macro]

[#-- Associations are only relevant for regional endpoints --]
[#macro createWAFAclAssociation id wafaclId endpointId dependencies=[] version="v1" ]
    [@cfResource
        id=id
        type=formatWAFResourceType("WebACLAssociation", true, version)
        properties=
            {
                "ResourceArn" : getArn(endpointId)
            } + (version == "v1")?then(
                    {
                        "WebACLId" : getReference(wafaclId)
                    },
                    {
                        "WebACLArn" : wafaclId
                    }
                )
        dependencies=dependencies
    /]
[/#macro]


[#macro enableWAFLogging wafaclId wafaclArn componentSubset deliveryStreamId="" deliveryStreamArns=[] regional=false version="v1" ]

    [#if regional ]
        [#local wafType = "regional" ]
    [#else]
        [#local wafType = "global" ]
    [/#if]

    [#switch version]
        [#case "v1"]
            [#if deliveryStreamId?has_content]
                [#if deploymentSubsetRequired("epilogue", false) ]
                    [@addToDefaultBashScriptOutput
                        content=[
                            r' case ${STACK_OPERATION} in',
                            r'   create|update)',
                            r'       manage_waf_logging ' +
                            r'          "' + getRegion() + r'"' +
                            r'          "' + wafaclId + r'"' +
                            r'          "' + wafType + r'"' +
                            r'          "enable"' +
                            r'          "' + deliveryStreamId + r'"' +
                            r'          || return $?',
                            r'       ;;',
                            r'    delete)',
                            r'       manage_waf_logging ' +
                            r'          "' + getRegion() + r'"' +
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
                            r'          "' + getRegion() + r'"' +
                            r'          "' + wafaclId + r'"' +
                            r'          "' + wafType + r'"' +
                            r'          "disable"' +
                            r'          || return $?',
                            r' esac'
                        ]
                    /]
                [/#if]
            [/#if]
        [#break]

        [#case "v2"]
            [#if deploymentSubsetRequired(componentSubset, true) ]
                [@cfResource
                    id=wafaclId+"Xlogconf"
                    type="AWS::WAFv2::LoggingConfiguration"
                    properties=
                            {
                                "LogDestinationConfigs": deliveryStreamArns,
                                "ResourceArn": wafaclArn
                            }
                /]
            [/#if]
        [#break]
    [/#switch]
[/#macro]
