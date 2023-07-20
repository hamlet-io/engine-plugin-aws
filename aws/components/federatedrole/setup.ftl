[#ftl]
[#macro aws_federatedrole_cf_deployment_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract subsets="template" /]
[/#macro]

[#macro aws_federatedrole_cf_deployment_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]
    [#local resources = occurrence.State.Resources]

    [#local identityPoolId = resources["identitypool"].Id ]
    [#local identityPoolName = resources["identitypool"].Name ]

    [#local roleMappingId = resources["rolemapping"].Id ]

    [#local federationProviders = {}]
    [#local federationCognitoProviders = [] ]

    [#list solution.Links as id,link]
        [#if link?is_hash]
            [#local linkTarget = getLinkTarget( occurrence, link ) ]

            [@debug message="Link Target" context=linkTarget enabled=false /]

            [#if !linkTarget?has_content]
                [#continue]
            [/#if]

            [#local linkTargetCore = linkTarget.Core ]
            [#local linkTargetConfiguration = linkTarget.Configuration ]
            [#local linkTargetResources = linkTarget.State.Resources ]
            [#local linkTargetAttributes = linkTarget.State.Attributes ]

            [#switch linkTargetCore.Type]
                [#case USERPOOL_CLIENT_COMPONENT_TYPE ]
                [#case USERPOOL_COMPONENT_TYPE ]

                    [#local userPoolName = linkTargetAttributes["USER_POOL_NAME"]!"" ]
                    [#local userPoolClient = linkTargetAttributes["CLIENT"]!"" ]

                    [#local federationProviders +=
                                {
                                    id : {
                                        "Provider" : concatenate( [ userPoolName, userPoolClient], ":" ),
                                        "Rules" : []
                                    }
                                }]

                    [#local federationCognitoProviders +=
                                getIdentityPoolCognitoProvider(
                                    userPoolName,
                                    userPoolClient
                                )]
                    [#break]
            [/#switch]
        [/#if]
    [/#list]

    [#if deploymentSubsetRequired(FEDERATEDROLE_COMPONENT_TYPE, true) ]
        [@createIdentityPool
            id=identityPoolId
            name=identityPoolName
            cognitoIdProviders=federationCognitoProviders
            allowUnauthenticatedIdentities=solution.AllowUnauthenticatedUsers
        /]
    [/#if]

    [#-- Assignment Management --]
    [#local authenticatedRole= ""]
    [#local unauthenticatedRole = ""]
    [#local ruleAssignments = {} ]

    [#local baselineLinks = getBaselineLinks(occurrence, [ "OpsData", "AppData", "Encryption", "SSHKey" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]

    [#list (occurrence.Occurrences![])?filter(x -> x.Configuration.Solution.Enabled ) as subOccurrence]

        [#local subCore = subOccurrence.Core ]
        [#local subSolution = subOccurrence.Configuration.Solution ]
        [#local subResources = subOccurrence.State.Resources ]

        [#if !subSolution.Enabled]
            [#continue]
        [/#if]

        [#local roleId = subResources["role"].Id ]

        [#local contextLinks = getLinkTargets(subOccurrence)]
        [#local _context =
            {
                "Links" : contextLinks,
                "Policy" : iamStandardPolicies(subOccurrence, baselineComponentIds),
                "ManagedPolicy" : [],
                "Assignment" : subCore.SubComponent.Id,
                "DefaultCoreVariables" : false,
                "DefaultEnvironmentVariables" : false,
                "DefaultLinkVariables" : false,
                "DefaultBaselineVariables" : false,
                "DefaultEnvironment" : defaultEnvironment(subOccurrence, contextLinks, {}),
                "Environment" : {}
            }
        ]
        [#-- Add in extension specifics including override of defaults --]
        [#local _context = invokeExtensions( subOccurrence, _context, occurrence )]

        [#switch subSolution.Type ]
            [#case "Authenticated" ]
                [#if ! authenticatedRole?has_content ]
                    [#local authenticatedRole = roleId ]
                [#else]
                    [@fatal
                        message="Only one assignment of this type is possible"
                        context=
                            {
                                "Type" : subSolution.Type,
                                "Asignment" : subOccurrence
                            }
                    /]
                [/#if]
                [#break]

            [#case "Unauthenticated" ]
                [#if ! unauthenticatedRole?has_content ]
                    [#local unauthenticatedRole = roleId ]
                [#else]
                    [@fatal
                        message="Only one assignment of this type is possible"
                        context=
                            {
                                "Type" : subSolution.Type,
                                "Asignment" : subOccurrence
                            }
                    /]
                [/#if]
                [#break]

            [#case "Rule" ]

                [#local mappingRule = getIdentityPoolMappingRule(
                                            (subSolution.Rule.Priority + subOccurrence?counter),
                                            subSolution.Rule.Claim,
                                            subSolution.Rule.MatchType,
                                            subSolution.Rule.Value,
                                            roleId
                                    )]

                [#list subSolution.Rule.Providers as provider ]
                    [#local federationProvider = (federationProviders[ provider ])!{} ]
                    [#if federationProvider?has_content]

                        [#local federationProviderRules = federationProvider["Rules"] + mappingRule ]


                        [#local federationProviders = mergeObjects( federationProviders,
                                                            {
                                                                provider : {
                                                                    "Rules" : federationProviderRules
                                                                }
                                                            }

                        )]
                    [/#if]
                [/#list]

                [#break]
        [/#switch]

        [#local policySet = {}]

        [#if deploymentSubsetRequired("iam", true) && isPartOfCurrentDeploymentUnit(roleId)]

            [#-- Managed Policies --]
            [#local policySet =
                addAWSManagedPoliciesToSet(
                    policySet,
                    _context.ManagedPolicy
                )
            ]

            [#local policySet =
                addInlinePolicyToSet(
                    policySet,
                    formatDependentPolicyId(subOccurrence.Core.Id, _context.Name),
                    _context.Name,
                    _context.Policy
                )
            ]

            [#-- Any permissions granted via links --]
            [#local policySet =
                addInlinePolicyToSet(
                    policySet,
                    formatDependentPolicyId(subOccurrence.Core.Id, "links"),
                    "links",
                    getLinkTargetsOutboundRoles(_context.Links)
                )
            ]

            [#-- Ensure we don't blow any limits as far as possible --]
            [#local policySet = adjustPolicySetForRole(policySet) ]

            [#-- Create any required managed policies --]
            [#-- They may result when policies are split to keep below AWS limits --]
            [@createCustomerManagedPoliciesFromSet policies=policySet /]


            [@createRole
                id=roleId
                federatedServices="cognito-identity.amazonaws.com"
                condition={
                    "ForAnyValue:StringLike": {
                        "cognito-identity.amazonaws.com:amr": valueIfTrue(
                                                                "unauthenticated",
                                                                subSolution.Type == "Unauthenticated",
                                                                "authenticated"
                        )
                    }
                } +
                attributeIfContent (
                    "StringEquals",
                    getExistingReference(identityPoolId),
                    {
                        "cognito-identity.amazonaws.com:aud": getExistingReference(identityPoolId)
                    }
                )
                managedArns=managedPolicies
                tags=getOccurrenceTags(subOccurrence)
            /]

            [#-- Create any inline policies that attach to the role --]
            [@createInlinePoliciesFromSet policies=policySet roles=roleId /]

        [/#if]
    [/#list]

    [#list federationProviders as id,federationProvider ]
        [#if federationProvider?is_hash ]
            [#if (federationProvider["Rules"]![])?has_content ]

                [#local providerRules = [] ]
                [#list federationProvider["Rules"]?sort_by("Priority") as rule  ]
                    [#local providerRules += [ rule.Rule ]]
                [/#list]

                [#local ruleAssignments +=
                        getIdentityPoolRoleMapping(
                            federationProvider["Provider"],
                            "Rules",
                            providerRules,
                            solution.NoMatchBehaviour
                        )]
            [/#if]
        [/#if]
    [/#list]

    [#-- Validate default auth/unauth role assignments --]
    [#if solution.AllowUnauthenticatedUsers && ! unauthenticatedRole?has_content ]
        [@fatal
            message="No unauthenicated assignments found"
            context=solution
        /]
    [/#if]

    [#if ! authenticatedRole?has_content ]
        [@fatal
            message="A default Authenticated Rule Assigment must be provided"
            context=solution
        /]
    [/#if]

    [#if deploymentSubsetRequired(FEDERATEDROLE_COMPONENT_TYPE, true) ]
        [@createIdentityPoolRoleMapping
            id=roleMappingId
            identityPoolId=identityPoolId
            roleMappings=ruleAssignments
            authenticatedRoleId=authenticatedRole
            unauthenticatedRoleId=unauthenticatedRole
        /]
    [/#if]
[/#macro]
