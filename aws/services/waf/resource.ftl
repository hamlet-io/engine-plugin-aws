[#ftl]

[#-- Regional resource types replicate global ones --]
[#function formatWAFResourceType baseResourceType regional ]
    [#return "AWS::WAFv2::" + baseResourceType ]
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
        [#case "METHOD"]
            [#local retVal += {
                "Method": {}
            }]
        [#break]
        [#case "BODY"]
            [#local retVal += {
                "JsonBody": {
                    "InvalidFallbackBehavior" : "EVALUATE_AS_STRING",
                    "OversizeHandling" : "CONTINUE",
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
    [#local statements = []]
    [#list conditions as condition]
        [#local v2WkStatement = []]

        [#list condition.Filters as filter]
            [#switch condition.Type]
                [#case WAF_SQL_INJECTION_MATCH_CONDITION_TYPE]
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

                [#case WAF_XSS_MATCH_CONDITION_TYPE]
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

                [#case WAF_BYTE_MATCH_CONDITION_TYPE]
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

                [#case WAF_SIZE_CONSTRAINT_CONDITION_TYPE]
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

                [#case WAF_GEO_MATCH_CONDITION_TYPE]
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

                [#case WAF_IP_MATCH_CONDITION_TYPE]
                    [#local v2WkStatement += [
                        {
                            "IPSetReferenceStatement": {
                                "Arn": getArn(
                                    formatDependentWAFConditionId(condition.Type, id, "c" + condition?counter?c)
                                )
                            }
                        }
                    ]]
                [#break]

                [#case WAF_REGEX_MATCH_CONDITION_TYPE]
                    [#list getWAFValueList(filter.FieldsToMatch, valueSet) as field]
                        [#local v2WkStatement += [
                            {
                                "RegexPatternSetReferenceStatement": {
                                    "Arn": getArn(
                                        formatDependentWAFConditionId(condition.Type, id, "c" + condition?counter?c)
                                    ),
                                    "FieldToMatch": formatV2FieldMatch(field),
                                    "TextTransformations": formatV2TextTransformations(filter.Transformations)
                                }
                            }
                        ]]
                    [/#list]
                [#break]

                [#case WAF_LABEL_MATCH_CONDITION_TYPE]
                    [#list getWAFValueList(filter.Targets, valueSet) as target]
                        [#local v2WkStatement += [
                            {
                                "LabelMatchStatement": {
                                    "Key": target,
                                    "Scope": filter["Type:LabelMatch"]["Scope"]
                                }
                            }
                        ]]
                    [/#list]
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
            [#local statements += [ { "NotStatement": {"Statement": v2WkStatement[0] }}] ]
        [#else]
            [#local statements += v2WkStatement]
        [/#if]
    [/#list]

    [#if statements?size > 1]
        [#local statements = { "AndStatement": { "Statements": statements}}]
    [#else]
        [#local statements = (statements[0])!{} ]
    [/#if]
    [#return statements]
[/#function]

[#-- Capture similarity between conditions --]
[#macro createWAFSetFromCondition id name conditionType filters=[] valueSet={} regional=false]

    [#local wafConditionDetails = getWAFConditionSetMappings(conditionType)]
    [#if ((wafConditionDetails.ResourceType)!{})?has_content]

        [#local hamletResourceType = wafConditionDetails["ResourceType"]["hamlet"]]
        [#local cfnResourceType = wafConditionDetails["ResourceType"]["cfn"]]

        [#switch hamletResourceType ]
            [#case AWS_WAFV2_IPSET_RESOURCE_TYPE]
                [@cfResource
                    id=id
                    type=cfnResourceType
                    properties=
                        {
                            "Name": name,
                            "Scope" : regional?then("REGIONAL","CLOUDFRONT"),
                            "IPAddressVersion" : "IPV4",
                            "Addresses": asFlattenedArray(
                                filters?map(filter ->
                                    getWAFValueList(filter.Targets, valueSet)
                                )
                            )
                        }
                /]
                [#break]

            [#case AWS_WAFV2_REGEX_PATTERN_SET_RESOURCE_TYPE]
                [@cfResource
                    id=id
                    type=cfnResourceType
                    properties=
                        {
                            "Name": name,
                            "Scope" : regional?then("REGIONAL","CLOUDFRONT"),
                            "RegularExpressionList": asFlattenedArray(
                                filters?map(filter ->
                                    getWAFValueList(filter.Targets, valueSet)
                                )
                            )
                        }
                /]
                [#break]
        [/#switch]
    [/#if]
[/#macro]


[#-- Creates the WAF Rule along with any MatchSets required for the conditions of the rule --]
[#macro setupWAFMatchSetsFromConditions id name conditions=[] valueSet={} regional=false ]
    [#local predicates = [] ]
    [#list asArray(conditions) as condition]
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
            [@createWAFSetFromCondition
                id=conditionId
                name=conditionName
                conditionType=condition.Type
                filters=condition.Filters
                valueSet=valueSet
                regional=regional
            /]
        [/#if]
    [/#list]
[/#macro]

[#-- Rules are grouped into bands. Bands are sorted into ascending alphabetic --]
[#-- order, with rules within a band ordered based on occurrence in the rules --]
[#-- array. Rules without a band are put into the default band.               --]
[#macro setupWAFAcl id name metric defaultAction rules=[] valueSet={} regional=false bandDefault="default" ]
    [#-- Determine the bands --]
    [#local bands = [] ]
    [#list asArray(rules) as rule]
        [#local bands += [rule.Band!bandDefault] ]
    [/#list]
    [#local bands = getUniqueArrayElements(bands)?sort]

    [#-- Priorities based on band order --]
    [#local aclRules = [] ]
    [#local customResponseBodies = {}]

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
                [@setupWAFMatchSetsFromConditions
                    id=ruleId
                    name=ruleName
                    conditions=rule.Conditions
                    valueSet=valueSet
                    regional=regional
                /]
            [/#if]

            [#local overrideAction = ""]
            [#local action = (rule.Action)?lower_case?cap_first ]
            [#local actionExtensions = {} ]

            [#if action == "Block" && (rule["Action:BLOCK"].CustomResponse.Enabled)!false ]
                [#local blockCustomResponse = rule["Action:BLOCK"].CustomResponse]

                [#local responseBodyContent = ""]
                [#if (rule["Action:BLOCK"].CustomResponse.Body.Content)?? ]
                    [#local responseBodyContent = rule["Action:BLOCK"].CustomResponse.Body.Content ]
                [#elseif (rule["Action:BLOCK"].CustomResponse.Body.ContentWAFValue)?? ]
                    [#local responseBodyContent = getWAFValueList(asArray(rule["Action:BLOCK"].CustomResponse.Body.ContentWAFValue), valueSet)?join("\n") ]
                [#else]
                    [@fatal
                        message="Missing custom block response body"
                        detail="Provider either a Body.Content or Body.ContentWAFValue entry"
                        context={
                            "Rule": ruleId,
                            "CustomReponse": blockCustomResponse
                        }
                    /]
                [/#if]

                [#local responseBodyContentType = ""]
                [#switch rule["Action:BLOCK"].CustomResponse.Body.ContentType ]
                    [#case "application/json"]
                        [#local responseBodyContentType = "APPLICATION_JSON"]
                        [#break]
                    [#case "text/html"]
                        [#local responseBodyContentType = "TEXT_HTML"]
                        [#break]
                    [#case "text/plain"]
                        [#local responseBodyContentType = "TEXT_PLAIN"]
                        [#break]
                    [#default]
                        [@fatal
                            message="Invalid Content Type for Block response"
                            context={
                                "Rule": ruleId,
                                "ContentType": rule["Action:BLOCK"].CustomResponse.Body.ContentType
                            }
                        /]
                [/#switch]

                [#local customResponseBodies = mergeObjects(
                        customResponseBodies,
                        {
                            ruleName : {
                                "Content": responseBodyContent,
                                "ContentType": responseBodyContentType
                            }
                        }
                    )
                ]

                [#local blockCustomResponeHeaders = [] ]
                [#if (blockCustomResponse.Headers)?has_content ]
                    [#list blockCustomResponse.Headers as k,v ]
                        [#local blockCustomResponeHeaders = combineEntities(
                            blockCustomResponeHeaders,
                            [
                                {
                                    "Name": (v.Key)!k,
                                    "Value": v.Value
                                }
                            ],
                            UNIQUE_COMBINE_BEHAVIOUR
                        )]
                    [/#list]
                [/#if]

                [#local actionExtensions = mergeObjects(
                    actionExtensions,
                    {
                        "CustomResponse": {
                            "CustomResponseBodyKey": ruleName,
                            "ResponseCode": blockCustomResponse.StatusCode
                        } +
                        attributeIfContent(
                            "ResponseHeaders",
                            blockCustomResponeHeaders
                        )
                    }
                )]
            [/#if]

            [#local statement = formatV2Conditions(rule.Conditions, valueSet, ruleId) ]

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

                    [#local statement = {
                        "RateBasedStatement" : rateLimitRule +
                            attributeIfTrue(
                                "ScopeDownStatement",
                                statement?has_content,
                                statement
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
                    [#local action = ""]
                    [#-- The recommendation from AWS is to always use None and then add overrides for particular rules in the group --]
                    [#-- https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-wafv2-webacl-overrideaction.html --]
                    [#local overrideAction =
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

                    [#local ruleActionOverrides = []]
                    [#list rule["Engine:VendorManaged"].ActionOverrides as k, override ]
                        [#local ruleActionOverrideRawName = (override.Name)!k ]

                        [#local ruleActionOverrideName = formatName(ruleName, ruleActionOverrideRawName) ]
                        [#local ruleActionOverrideId = formatId(ruleId, ruleActionOverrideRawName) ]

                        [#local ruleActionOverride = {}]

                        [#switch override.Action]
                            [#case "BLOCK"]
                            [#case "ALLOW"]
                            [#case "COUNT"]
                                [#local ruleActionOverride = { (override.Action)?lower_case?cap_first : {}}]
                                [#break]
                        [/#switch]

                        [#local ruleActionOverrides = combineEntities(
                            ruleActionOverrides,
                            [
                                {
                                    "Name": ruleActionOverrideRawName,
                                    "ActionToUse": ruleActionOverride
                                }
                            ],
                            APPEND_COMBINE_BEHAVIOUR
                        )]

                    [/#list]

                    [#local statement = {
                        "ManagedRuleGroupStatement" : vendorManagedRule +
                            attributeIfTrue(
                                "ScopeDownStatement",
                                statement?has_content,
                                statement
                            ) +
                            attributeIfContent(
                                "RuleActionOverrides",
                                ruleActionOverrides
                            )
                    }]
                    [#break]
            [/#switch]

            [#local aclRules +=
                [
                    {
                        "Name" : ruleName,
                        "Priority" : nextRulePriority,
                        "Statement" : statement,
                        "VisibilityConfig" : {
                            "CloudWatchMetricsEnabled" : true,
                            "MetricName" : ruleName,
                            "SampledRequestsEnabled" : true
                        }
                    } +
                    attributeIfContent(
                        "Action",
                        action,
                        {
                            action: actionExtensions
                        }
                    ) +
                    attributeIfContent(
                        "OverrideAction",
                        overrideAction
                    )
                ]
            ]
            [#local nextRulePriority += 1]
        [/#list]
    [/#list]

    [#local properties={
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
    } +
    attributeIfContent(
        "CustomResponseBodies",
        customResponseBodies
    )]

    [@cfResource
        id=id
        type=formatWAFResourceType("WebACL", regional)
        properties=properties
    /]
[/#macro]

[#macro createWAFAclFromSecurityProfile id name metric wafSolution securityProfile occurrence={} regional=false ]
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
        }]
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
        }]
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
        }]
        [#local wafProfile += {
                "Rules" :
                    wafProfile.Rules +
                    [
                        {
                            "Rule" : "blacklistcountries",
                            "Action" : "BLOCK",
                            "Action:BLOCK": {
                                "CustomResponse": {
                                    "Enabled": false
                                }
                            }
                        }
                    ],
                "DefaultAction" : "ALLOW"
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
                            "Action" : "Block"
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
    /]
[/#macro]

[#-- Associations are only relevant for regional endpoints --]
[#macro createWAFAclAssociation id wafaclId endpointId dependencies=[]  ]
    [@cfResource
        id=id
        type=formatWAFResourceType("WebACLAssociation", true)
        properties=
            {
                "ResourceArn" : getArn(endpointId),
                "WebACLArn" : wafaclId
            }
        dependencies=dependencies
    /]
[/#macro]


[#macro enableWAFLogging wafaclId wafaclArn componentSubset deliveryStreamId="" deliveryStreamArns=[] regional=false ]

    [#if regional ]
        [#local wafType = "regional" ]
    [#else]
        [#local wafType = "global" ]
    [/#if]

    [#if deploymentSubsetRequired(componentSubset, true) ]
        [@cfResource
            id=formatResourceId(wafaclId, "logconf")
            type="AWS::WAFv2::LoggingConfiguration"
            properties=
                {
                    "LogDestinationConfigs": deliveryStreamArns,
                    "ResourceArn": wafaclArn
                }
        /]
    [/#if]
[/#macro]
