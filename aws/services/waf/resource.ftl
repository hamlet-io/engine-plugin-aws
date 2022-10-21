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

[#function formatV2Conditions conditions valueSet={} id=""]
    [#local v2Statements = []]
    [#list conditions as condition]
        [#local v2WkStatement = []]

        [#list condition.Filters as filter]
            [#switch condition.Type]
                [#case AWS_WAF_SQL_INJECTION_MATCH_CONDITION_TYPE]
                    [#list getWAFValueList(filter.FieldsToMatch, valueSet) as field]
                        [#local v2WkStatement += [
                            {
                                "SqliMatchStatement": {
                                    "FieldToMatch": formatV2FieldMatch(field),
                                    "TextTransformations": formatV2TextTransformations(filter.Transformations)
                                }
                            }
                        ]]
                    [/#list]
                [#break]

                [#case AWS_WAF_XSS_MATCH_CONDITION_TYPE]
                    [#list getWAFValueList(filter.FieldsToMatch, valueSet) as field]
                        [#local v2WkStatement += [
                            {
                                "XssMatchStatement": {
                                    "FieldToMatch": formatV2FieldMatch(field),
                                    "TextTransformations": formatV2TextTransformations(filter.Transformations)
                                }
                            }
                        ]]
                    [/#list]
                [#break]

                [#case AWS_WAF_BYTE_MATCH_CONDITION_TYPE]
                    [#list getWAFValueList(filter.FieldsToMatch, valueSet) as field]
                        [#list getWAFValueList(filter.Constraints, valueSet) as constraint]
                            [#list getWAFValueList(filter.Targets, valueSet) as target]
                                [#local v2WkStatement += [
                                    {
                                        "ByteMatchStatement": {
                                            "FieldToMatch": formatV2FieldMatch(field),
                                            "PositionalConstraint" : constraint,
                                            "SearchString" : target,
                                            "TextTransformations": formatV2TextTransformations(filter.Transformations)
                                        }
                                    }
                                ]]
                            [/#list]
                        [/#list]
                    [/#list]
                [#break]

                [#case AWS_WAF_SIZE_CONSTRAINT_CONDITION_TYPE]
                    [#list getWAFValueList(filter.FieldsToMatch, valueSet) as field]
                        [#list getWAFValueList(filter.Operators, valueSet) as operator]
                            [#list getWAFValueList(filter.Sizes, valueSet) as size]
                                [#local v2WkStatement += [
                                    {
                                        "SizeConstraintStatement": {
                                            "ComparisonOperator": operator,
                                            "FieldToMatch": formatV2FieldMatch(field),
                                            "TextTransformations": formatV2TextTransformations(filter.Transformations),
                                            "Size": size
                                        }
                                    }
                                ]]
                            [/#list]
                        [/#list]
                    [/#list]
                [#break]

                [#case AWS_WAF_GEO_MATCH_CONDITION_TYPE]
                    [#local v2WkGeo = []]
                    [#list getWAFValueList(filter.Targets, valueSet) as target]
                        [#local v2WkGeo += [ target] ]
                    [/#list]
                    [#local v2WkStatement += [
                        {
                            "GeoMatchStatement": {
                                "CountryCodes": v2WkGeo
                            }
                        }
                    ]]
                [#break]

                [#case AWS_WAF_IP_MATCH_CONDITION_TYPE]
                    [#local v2WkStatement += [
                        {
                            "IPSetReferenceStatement": {
                                "Arn": getArn(
                                    formatDependentWAFConditionId("v2", condition.Type, id, "c" + condition?counter?c)
                                )
                            }
                        }
                    ]]
                [#break]

                [#default]
                    [#local v2WkStatement += [ { "HamletFatal:UnknownStatement": condition } ]]
                    [@fatal message="Unknown WAF statement type" context=filter /]
                [#break]
            [/#switch]
        [/#list]

        [#if v2WkStatement?size > 1]
            [#local v2WkStatement = [ {"OrStatement": { "Statements": v2WkStatement}}]]
        [/#if]

        [#if condition.Negated]
            [#local v2Statements += [ { "NotStatement": {"Statement": v2WkStatement[0] }}] ]
        [#else]
            [#local v2Statements += v2WkStatement]
        [/#if]
    [/#list]

    [#if v2Statements?size > 1]
        [#local v2Statements = { "AndStatement": { "Statements": v2Statements}}]
    [#else]
        [#local v2Statements = (v2Statements[0])!{} ]
    [/#if]
    [#return v2Statements]
[/#function]

[#-- Capture similarity between conditions --]
[#macro createWAFMatchSetFromCondition id name conditionType filters=[] valueSet={} regional=false version="v1"]

    [#local wafConditionDetails = getWAFConditionSetMappings(conditionType)]
    [#if ((wafConditionDetails.ResourceType[version])!{})?has_content]

        [#local hamletResourceType = wafConditionDetails["ResourceType"][version]["hamlet"]]
        [#local cfnResourceType = ""]

        [#switch version ]
            [#case "v1"]
                [#if regional ]
                    [#local cfnResourceType = wafConditionDetails["ResourceType"][version]["cfn"]["regional"]]
                [#else]
                    [#local cfnResourceType = wafConditionDetails["ResourceType"][version]["cfn"]["global"]]
                [/#if]
                [#break]
            [#case "v2"]
                [#local cfnResourceType = wafConditionDetails["ResourceType"][version]["cfn"] ]
                [#break]
        [/#switch]

        [#local result = [] ]
        [#list asArray(filters) as filter]
            [#switch conditionType]
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
            type=cfnResourceType
            properties=
                {
                    "Name": name
                } +
                (version == "v2")?then(
                    {
                        "Scope" : regional?then("REGIONAL","CLOUDFRONT")
                    },
                    {}
                )+
                ((conditionType == "IPMatch") && (version == "v2"))?then(
                    {
                        "IPAddressVersion" : "IPV4"
                    },
                    {}
                )+
                contentIfContent(
                    attributeIfContent(
                        ((conditionType == "IPMatch") && (version == "v2"))?then(
                            "Addresses",
                            wafConditionDetails.TuplesAttributeKey!""
                        ),
                        result
                    ),
                    result
                )
        /]
    [/#if]
[/#macro]


[#-- Creates the WAF Rule along with any MatchSets required for the conditions of the rule --]
[#macro setupWAFRule id name metric conditions=[] valueSet={} regional=false rateKey="" rateLimit="" version="v1"]
    [#local predicates = [] ]
    [#list asArray(conditions) as condition]
        [#local rateBased = (rateKey?has_content && rateLimit?has_content)]
        [#local conditionId = condition.Id!""]
        [#local conditionName = condition.Name!conditionId]
        [#-- Generate id/name from rule equivalents if not provided --]
        [#if !conditionId?has_content]
            [#local conditionId = formatDependentWAFConditionId(version, condition.Type, id, "c" + condition?counter?c)]
        [/#if]
        [#if !conditionName?has_content]
            [#local conditionName = formatName(name,"c" + condition?counter?c,condition.Type)]
        [/#if]
        [#if condition.Filters?has_content]
            [#-- Condition to be created with the rule --]
            [@createWAFMatchSetFromCondition
                id=conditionId
                name=conditionName
                conditionType=condition.Type
                filters=condition.Filters
                valueSet=valueSet
                regional=regional
                version=version
            /]
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

    [#if version == "v1"]
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
    [/#if]
[/#macro]

[#-- Rules are grouped into bands. Bands are sorted into ascending alphabetic --]
[#-- order, with rules within a band ordered based on occurrence in the rules --]
[#-- array. Rules without a band are put into the default band.               --]
[#macro setupWAFAcl id name metric defaultAction rules=[] valueSet={} regional=false bandDefault="default" version="v1" ]
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
                [#local ruleId = formatDependentWAFRuleId(version, id,"r" + rule?counter?c)]
            [/#if]
            [#if !ruleName?has_content]
                [#local ruleName = formatName(name,"r" + rule?counter?c,rule.NameSuffix!"")]
            [/#if]
            [#if !ruleMetric?has_content]
                [#local ruleMetric = formatId(metric,"r" + rule?counter?c)]
            [/#if]
            [#if rule.Conditions?has_content]
                [@setupWAFRule
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
                    [#switch rule.Engine ]
                        [#case "Conditional" ]
                            [#break]
                        [#default]
                            [@fatal
                                message="Unsupported engine for WAF V1 - Only the conditional engine is available"
                                context={
                                    "WafId": id,
                                    "Rule": rule
                                }
                            /]
                    [/#switch]
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
                    [#local v2OverrideAction = ""]
                    [#local v2Action = (rule.Action)?lower_case?cap_first]
                    [#local v2Statement = formatV2Conditions(rule.Conditions, valueSet, ruleId) ]

                    [#local rateLimitRule = {}]
                    [#switch rule.Engine ]
                        [#case "Conditional" ]
                            [#break]

                        [#case "RateLimit"]
                            [#if ! (rule["Engine:RateLimit"].Limit)?has_content]
                                [@fatal
                                    message="Limit required when RateLimit is enabled for WAF Condition"
                                    context={
                                        "WafId": id,
                                        "Rule": rule
                                    }
                                /]
                                [#continue]
                            [/#if]

                            [#local rateLimitRule = {
                                "AggregateKeyType": (rule["Engine:RateLimit"].IPAddressSource == "ClientIP")?then(
                                    "IP",
                                    "FORWARDED_IP"
                                ),
                                "Limit": (rule["Engine:RateLimit"].Limit)!0
                            } +
                            attributeIfTrue(
                                "ForwardedIPConfig",
                                rule["Engine:RateLimit"].IPAddressSource == "HTTPHeader",
                                {
                                    "HeaderName": rule["Engine:RateLimit"]["IPAddressSource:HTTPHeader"].HeaderName,
                                    "FallbackBehavior": (rule["Engine:RateLimit"]["IPAddressSource:HTTPHeader"].ApplyLimitWhenMissing)?then(
                                        "MATCH",
                                        "NO_MATCH"
                                    )
                                }
                            )]

                            [#local v2Statement = {
                                "RateBasedStatement" : rateLimitRule +
                                    attributeIfTrue(
                                        "ScopeDownStatement",
                                        v2Statement?has_content,
                                        v2Statement
                                    )
                            }]
                            [#break]

                        [#case "VendorManaged"]
                            [#if ! ( (rule["Engine:VendorManaged"].Vendor)?has_content || (rule["Engine:VendorManaged"].RuleName)?has_content )]
                                [@fatal
                                    message="Engine:VendorManaged.Vendor and Engine:VendorManaged.RuleName required when using a Vendor Managed Rule"
                                    context={
                                        "WafId": id,
                                        "Rule": rule
                                    }
                                /]
                                [#continue]
                            [/#if]

                            [#-- Actions are controlled by the indvidual rules within a vendor managed group --]
                            [#local v2Action = ""]
                            [#-- The recommendation from AWS is to always use None and then add overrides for particular rules in the group --]
                            [#-- https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-wafv2-webacl-overrideaction.html --]
                            [#local v2OverrideAction =
                                {
                                    "None": {}
                                }
                            ]

                            [#local vendorManagedRule = {
                                "Name": (rule["Engine:VendorManaged"].RuleName)!"",
                                "VendorName": (rule["Engine:VendorManaged"].Vendor)!""
                            } +
                            attributeIfContent(
                                "Version",
                                 (rule["Engine:VendorManaged"].RuleVersion)!""
                            ) +
                            attributeIfContent(
                                "ManagedRuleGroupConfigs",
                                (rule["Engine:VendorManaged"].Parameters)!{},
                                asArray(rule["Engine:VendorManaged"].Parameters)
                            ) +
                            attributeIfContent(
                                "ExcludedRules",
                                rule["Engine:VendorManaged"].DisabledRules
                            )]

                            [#local v2Statement = {
                                "ManagedRuleGroupStatement" : vendorManagedRule +
                                    attributeIfTrue(
                                        "ScopeDownStatement",
                                        v2Statement?has_content,
                                        v2Statement
                                    )
                            }]
                            [#break]
                    [/#switch]

                    [#local aclRules +=
                        [
                            {
                                "Name" : ruleName,
                                "Priority" : nextRulePriority,
                                "Statement" : v2Statement,
                                "VisibilityConfig" : {
                                    "CloudWatchMetricsEnabled" : true,
                                    "MetricName" : ruleName,
                                    "SampledRequestsEnabled" : true
                                }
                            } +
                            attributeIfContent(
                                "Action",
                                v2Action,
                                {
                                    v2Action: {}
                                }
                            ) +
                            attributeIfContent(
                                "OverrideAction",
                                v2OverrideAction
                            )
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
            [#local properties=
                {
                    "DefaultAction" : {
                        defaultAction?lower_case?cap_first : {}
                    },
                    "Name": name,
                    "Rules" : aclRules,
                    "Scope": regional?then("REGIONAL","CLOUDFRONT"),
                    "VisibilityConfig" : {
                        "CloudWatchMetricsEnabled" : true,
                        "MetricName" : name,
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
    [#if wafSolution.OWASP ]
        [#local wafProfile = getReferenceData(WAFPROFILE_REFERENCE_TYPE)[("OWASP2017")]!{}]
    [#else]
        [#local wafProfile = getReferenceData(WAFPROFILE_REFERENCE_TYPE)[(securityProfile.WAFProfile)]!{} ]
    [/#if]

    [#local wafValueSet = resolveDynamicValues(
        getReferenceData(WAFVALUESET_REFERENCE_TYPE)[securityProfile.WAFValueSet!""]!{},
        {"occurrence": occurrence}
    )]

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
    [#local rules = getWAFProfileRules(
        wafProfile,
        getReferenceData(WAFRULEGROUP_REFERENCE_TYPE),
        getReferenceData(WAFRULE_REFERENCE_TYPE),
        getReferenceData(WAFCONDITION_REFERENCE_TYPE)
    )]

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

    [@setupWAFAcl
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
