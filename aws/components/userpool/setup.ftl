[#ftl]
[#macro aws_userpool_cf_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract subsets=["template" ] /]
[/#macro]

[#macro aws_userpool_cf_setup_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]
    [#local resources = occurrence.State.Resources]

    [#local userPoolId                 = resources["userpool"].Id]
    [#local userPoolName               = resources["userpool"].Name]

    [#local userPoolRoleId             = resources["role"].Id]

    [#local userPoolDomainId           = resources["domain"].Id]
    [#local userPoolHostName           = resources["domain"].Name]
    [#local customDomainRequired       = ((resources["customdomain"].Id)!"")?has_content ]
    [#if customDomainRequired ]
        [#local userPoolCustomDomainId = resources["customdomain"].Id ]
        [#local userPoolCustomDomainName = resources["customdomain"].Name ]
        [#local userPoolCustomDomainCertArn = resources["customdomain"].CertificateArn]

        [#if ! userPoolCustomDomainCertArn?has_content ]
            [@fatal
                message="ACM Certificate required in us-east-1"
                context=resources
                enabled=true
            /]
        [/#if]
    [/#if]

    [#local smsVerification = false]
    [#local userPoolTriggerConfig = {}]
    [#local smsConfig = {}]
    [#local authProviders = []]

    [#local defaultUserPoolClientRequired = false ]
    [#local defaultUserPoolClientConfigured = false ]

    [#if (resources["client"]!{})?has_content]
        [#local defaultUserPoolClientRequired = true ]
        [#local defaultUserPoolClientId = resources["client"].Id]
    [/#if]

    [#local mfaRequired = false ]

    [#if solution.MFA?is_string ]
        [#switch solution.MFA ]
            [#case "true" ]
            [#case "optional" ]
                [#local mfaRequired = true ]
                [#break]
        [/#switch]

        [#switch solution.MFA ]
            [#case "true"]
                [#local mfaConfig="ON"]
                [#break]
            [#case "false"]
                [#local mfaConfig="OFF"]
                [#break]
            [#case "optional" ]
                [#local mfaConfig="OPTIONAL"]
                [#break]
            [#default]
                [#local mfaConfig="COTFatal: Unkown MFA config option" ]
        [/#switch]

    [#else ]
        [#local mfaRequired = solution.MFA]
        [#local mfaConfig = mfaRequired?then("ON", "OFF") ]
    [/#if]

    [#local deviceTrackingConfig = {}]
    [#if solution.Security.UserDeviceTracking?is_boolean ]
        [#if solution.Security.UserDeviceTracking ]
            [#local deviceTrackingConfig = {
                "ChallengeRequiredOnNewDevice" : true,
                "DeviceOnlyRememberedOnUserPrompt" : false
            }]
        [#else]
            [#local deviceTrackingConfig = {}]
        [/#if]
    [#else]
        [#switch solution.Security.UserDeviceTracking ]
            [#case "true" ]
                [#local deviceTrackingConfig = {
                    "ChallengeRequiredOnNewDevice" : true,
                    "DeviceOnlyRememberedOnUserPrompt" : false
                }]
                [#break]

            [#case "false" ]
                [#local deviceTrackingConfig = {}]
                [#break]

            [#case "optional" ]
                [#local deviceTrackingConfig = {
                    "ChallengeRequiredOnNewDevice" : true,
                    "DeviceOnlyRememberedOnUserPrompt" : true
                }]
                [#break]
        [/#switch]
    [/#if]

    [#local loginAliases = solution.Username.Aliases ]
    [#if (solution.LoginAliases )?has_content ]
        [@fatal
            message="LoginAliases deprecated"
            detail="LoginAliases has been moved to Username.Aliases"
            context={
                "LoginAliases" : solution.LoginAliases
            }
        /]
    [/#if]

    [#if (solution.Username.Aliases )?has_content && ( solution.Username.Attributes )?has_content ]
        [@fatal
            message="Username Aliases and Attributes defined"
            detail="Can only assign aliases or attributes"
            context={
                "Username" : solution.Username
            }
        /]
    [/#if]

    [#local userPoolClientUpdateCommand = "updateUserPoolClient" ]
    [#local userPoolDomainCommand = "setDomainUserPool" ]
    [#local userPoolAuthProviderUpdateCommand = "updateUserPoolAuthProvider" ]

    [#local emailVerificationMessage =
        getOccurrenceSettingValue(occurrence, ["UserPool", "EmailVerificationMessage"], true) ]

    [#local emailVerificationSubject =
        getOccurrenceSettingValue(occurrence, ["UserPool", "EmailVerificationSubject"], true) ]

    [#local smsVerificationMessage =
        getOccurrenceSettingValue(occurrence, ["UserPool", "SMSVerificationMessage"], true) ]

    [#local emailInviteMessage =
        getOccurrenceSettingValue(occurrence, ["UserPool", "EmailInviteMessage"], true) ]

    [#local emailInviteSubject =
        getOccurrenceSettingValue(occurrence, ["UserPool", "EmailInviteSubject"], true) ]

    [#local smsInviteMessage =
        getOccurrenceSettingValue(occurrence, ["UserPool", "SMSInviteMessage"], true) ]

    [#local smsAuthenticationMessage =
        getOccurrenceSettingValue(occurrence, ["UserPool", "SMSAuthenticationMessage"], true) ]

    [#local schema = []]
    [#list solution.Schema as key,schemaAttribute ]
        [#local schema +=  getUserPoolSchemaObject(
                            key,
                            schemaAttribute.DataType,
                            schemaAttribute.Mutable,
                            schemaAttribute.Required
        )]
    [/#list]

    [#if ((mfaRequired) || ( solution.VerifyPhone))]
        [#if ! (solution.Schema["phone_number"]!"")?has_content ]
            [@fatal
                message="Schema Attribute required: phone_number - Add Schema listed in detail"
                context=schema
                detail={
                    "phone_number" : {
                        "DataType" : "String",
                        "Mutable" : true,
                        "Required" : true
                    }
                }/]
        [/#if]

        [#local smsConfig = getUserPoolSMSConfiguration( getReference(userPoolRoleId, ARN_ATTRIBUTE_TYPE), userPoolName )]
        [#local smsVerification = true]
    [/#if]

    [#if solution.VerifyEmail || loginAliases?seq_contains("email")]
        [#if ! (solution.Schema["email"]!"")?has_content ]
            [@fatal
                message="Schema Attribute required: email - Add Schema listed in detail"
                context=schema
                detail={
                    "email" : {
                        "DataType" : "String",
                        "Mutable" : true,
                        "Required" : true
                    }
                }/]
        [/#if]
    [/#if]

    [#list solution.Links?values as link]
        [#local linkTarget = getLinkTarget(occurrence, link)]

        [@debug message="Link Target" context=linkTarget enabled=false /]

        [#if !linkTarget?has_content]
            [#continue]
        [/#if]

        [#local linkTargetCore = linkTarget.Core]
        [#local linkTargetConfiguration = linkTarget.Configuration ]
        [#local linkTargetResources = linkTarget.State.Resources]
        [#local linkTargetAttributes = linkTarget.State.Attributes]

        [#switch linkTargetCore.Type]

            [#case LAMBDA_FUNCTION_COMPONENT_TYPE]

                [#-- Cognito Userpool Event Triggers --]
                [#switch link.Name?lower_case]
                    [#case "createauthchallenge"]
                        [#local userPoolTriggerConfig +=
                            attributeIfContent (
                                "CreateAuthChallenge",
                                linkTargetAttributes.ARN
                            )
                        ]
                        [#break]
                    [#case "custommessage"]
                        [#local userPoolTriggerConfig +=
                            attributeIfContent (
                                "CustomMessage",
                                linkTargetAttributes.ARN
                            )
                        ]
                        [#break]
                    [#case "defineauthchallenge"]
                        [#local userPoolTriggerConfig +=
                            attributeIfContent (
                                "DefineAuthChallenge",
                                linkTargetAttributes.ARN
                            )
                        ]
                        [#break]
                    [#case "postauthentication"]
                        [#local userPoolTriggerConfig +=
                            attributeIfContent (
                                "PostAuthentication",
                                linkTargetAttributes.ARN
                            )
                        ]
                        [#break]
                    [#case "postconfirmation"]
                        [#local userPoolTriggerConfig +=
                            attributeIfContent (
                                "PostConfirmation",
                                linkTargetAttributes.ARN
                            )
                        ]
                        [#break]
                    [#case "preauthentication"]
                        [#local userPoolTriggerConfig +=
                            attributeIfContent (
                                "PreAuthentication",
                                linkTargetAttributes.ARN
                            )
                        ]
                        [#break]
                    [#case "presignup"]
                        [#local userPoolTriggerConfig +=
                            attributeIfContent (
                                "PreSignUp",
                                linkTargetAttributes.ARN
                            )
                        ]
                        [#break]
                    [#case "verifyauthchallengeresponse"]
                        [#local userPoolTriggerConfig +=
                            attributeIfContent (
                                "VerifyAuthChallengeResponse",
                                linkTargetAttributes.ARN
                            )
                        ]
                        [#break]
                    [#case "pretokengeneration"]
                        [#local userPoolTriggerConfig +=
                            attributeIfContent (
                                "PreTokenGeneration",
                                linkTargetAttributes.ARN
                            )
                        ]
                        [#break]
                    [#case "usermigration"]
                        [#local userPoolTriggerConfig +=
                            attributeIfContent (
                                "UserMigration",
                                linkTargetAttributes.ARN
                            )
                        ]
                        [#break]
                [/#switch]
            [#break]
        [/#switch]
    [/#list]


    [#if ((mfaRequired) || ( solution.VerifyPhone))]
        [#if (deploymentSubsetRequired("iam", true) || deploymentSubsetRequired("userpool", true)) &&
            isPartOfCurrentDeploymentUnit(userPoolRoleId)]

                [@createRole
                    id=userPoolRoleId
                    trustedServices=["cognito-idp.amazonaws.com"]
                    policies=
                        [
                            getPolicyDocument(
                                snsPublishPermission(),
                                "smsVerification"
                            )
                        ]
                /]
        [/#if]
    [/#if]

    [#local authProviderEpilogue = []]
    [#local userPoolClientEpilogue = []]

    [#list occurrence.Occurrences![] as subOccurrence]

        [#local subCore = subOccurrence.Core ]
        [#local subSolution = subOccurrence.Configuration.Solution ]
        [#local subResources = subOccurrence.State.Resources ]

        [#if !subSolution.Enabled]
            [#continue]
        [/#if]

        [#if subCore.Type == USERPOOL_AUTHPROVIDER_COMPONENT_TYPE ]

            [#local authProviderId = subResources["authprovider"].Id ]
            [#local authProviderName = subResources["authprovider"].Name ]
            [#local authProviderEngine = subSolution.Engine]
            [#local settingsPrefix = subSolution.SettingsPrefix?upper_case?ensure_ends_with("_") ]

            [#local linkTargets = getLinkTargets(subOccurrence) ]
            [#local baselineLinks = getBaselineLinks(subOccurrence, [] )]
            [#local environment = defaultEnvironment( occurrence, linkTargets,  baselineLinks )]

            [#local authProviders += [ authProviderName ]]

            [#local attributeMappings = {} ]
            [#list subSolution.AttributeMappings as id, attributeMapping ]
                [#local localAttribute = attributeMapping.UserPoolAttribute?has_content?then(
                                            attributeMapping.UserPoolAttribute,
                                            id
                )]

                [#local attributeMappings += {
                    localAttribute : attributeMapping.ProviderAttribute
                }]
            [/#list]

            [#switch authProviderEngine ]
                [#case "Google"]
                [#case "Amazon"]
                    [#local providerDetails = {
                        "client_id" : valueIfContent(
                                            (subSolution[authProviderName].ClientId)!"",
                                            (environment[ settingsPrefix + "_" + authProviderName?upper_case + "_CLIENT_ID"])!"COTFatal: ClientId not defined"
                        ),
                        "client_secret" : valueIfContent(
                                            (subSolution[authProviderName].ClientSecret)!"",
                                            (environment[ settingsPrefix + "_" + authProviderName?upper_case + "_CLIENT_SECRET"])!"COTFatal: ClientSecret not defined"
                        ),
                        "authorize_scopes" : valueIfContent(
                                            (subSolution[authProviderName].Scopes)!"",
                                            (environment[ settingsPrefix + "_" + authProviderName?upper_case + "_SCOPES"])!"COTFatal: Scopes not defined"
                        )
                    }]
                    [#break]

                [#case "Facebook" ]
                    [#local providerDetails = {
                        "client_id" : valueIfContent(
                                            (subSolution[authProviderName].ClientId)!"",
                                            (environment[ settingsPrefix + "_" + authProviderName?upper_case + "_CLIENT_ID"])!"COTFatal: ClientId not defined"
                        ),
                        "client_secret" : valueIfContent(
                                            (subSolution[authProviderName].ClientSecret)!"",
                                            (environment[ settingsPrefix + "_" + authProviderName?upper_case + "_CLIENT_SECRET"])!"COTFatal: ClientSecret not defined"
                        ),
                        "authorize_scopes" : valueIfContent(
                                            (subSolution[authProviderName].Scopes)!"",
                                            (environment[ settingsPrefix + "_" + authProviderName?upper_case + "_SCOPES"])!"COTFatal: Scopes not defined"
                        ),
                        "api_version" : valueIfContent(
                                            (subSolution[authProviderName].APIVersion)!"",
                                            (environment[ settingsPrefix + "_" + authProviderName?upper_case + "_API_VERSION"])!"COTFatal: APIVersion not defined"
                        )
                    }]
                    [#break]

                [#case "Apple"]
                    [#local providerDetails = {
                        "client_id" : valueIfContent(
                                            (subSolution[authProviderName].ClientId)!"",
                                            (environment[ settingsPrefix + "_" + authProviderName?upper_case + "_CLIENT_ID"])!"COTFatal: ClientId not defined"
                        ),
                        "team_id" : valueIfContent(
                                            (subSolution[authProviderName].TeamId)!"",
                                            (environment[ settingsPrefix + "_" + authProviderName?upper_case + "_TEAM_ID"])!"COTFatal: TeamId not defined"
                        ),
                        "key_id" : valueIfContent(
                                            (subSolution[authProviderName].KeyId)!"",
                                            (environment[ settingsPrefix + "_" + authProviderName?upper_case + "_KEY_ID"])!"COTFatal: KeyId not defined"
                        ),
                        "private_key" : valueIfContent(
                                            (subSolution[authProviderName].PrivateKey)!"",
                                            (environment[ settingsPrefix + "_" + authProviderName?upper_case + "_PRIVATE_KEY"])!"COTFatal: PrivateKey not defined"
                        ),
                        "authorize_scopes" : valueIfContent(
                                            (subSolution[authProviderName].Scopes)!"",
                                            (environment[ settingsPrefix + "_" + authProviderName?upper_case + "_SCOPES"])!"COTFatal: Scopes not defined"
                        )
                    }]
                    [#break]

                [#case "SAML" ]
                    [#local providerDetails = {
                        "MetadataURL" : valueIfContent(
                                            (subSolution.SAML.MetadataUrl)!"",
                                            (environment[ settingsPrefix + "SAML_METADATA_URL"])!"COTFatal: MetadataUrl not defined"
                        ),
                        "IDPSignout" :  subSolution.SAML.EnableIDPSignOut
                    }]
                    [#break]

                [#case "OIDC" ]

                    [#local providerDetails = {
                        "client_id" : valueIfContent(
                                            (subSolution.OIDC.ClientId)!"",
                                            (environment[ settingsPrefix + "OIDC_CLIENT_ID"])!"COTFatal: ClientId not defined"
                        ),
                        "client_secret" : valueIfContent(
                                            (subSolution.OIDC.ClientSecret)!"",
                                            (environment[settingsPrefix + "OIDC_CLIENT_SECRET"])!"COTFatal: ClientSecret not defined"
                        ),
                        "authorize_scopes" : valueIfContent(
                                                (subSolution.OIDC.Scopes?join(" "))!"",
                                                (environment[settingsPrefix + "OIDC_SCOPES"])!"COTFatal: Scopes not defined"
                        ),
                        "attributes_request_method" : valueIfContent(
                                                (subSolution.OIDC.AttributesHttpMethod)!"",
                                                (environment[settingsPrefix + "OIDC_ATTRIBUTES_HTTP_METHOD"])!"COTFatal: AttributesHttpMethod not defined"
                        ),
                        "oidc_issuer" : valueIfContent(
                                                (subSolution.OIDC.Issuer)!"",
                                                (environment[settingsPrefix + "OIDC_ISSUER"])!"COTFatal: Issuer not defined"
                        )
                    } +
                    attributeIfContent(
                        "authorize_url",
                        valueIfContent(
                            (subSolution.OIDC.AuthorizeUrl)!"",
                            (environment[settingsPrefix + "OIDC_AUTHORIZE_URL"])!""
                        )
                    ) +
                    attributeIfContent(
                        "token_url",
                        valueIfContent(
                            (subSolution.OIDC.TokenUrl)!"",
                            (environment[settingsPrefix + "OIDC_TOKEN_URL"])!""
                        )
                    ) +
                    attributeIfContent(
                        "attributes_url",
                        valueIfContent(
                            (subSolution.OIDC.AttributesUrl)!"",
                            (environment[settingsPrefix + "OIDC_ATTRIBUTES_URL"])!""
                        )
                    ) +
                    attributeIfContent(
                        "jwks_uri",
                        valueIfContent(
                            (subSolution.OIDC.JwksUrl)!"",
                            (environment[settingsPrefix + "OIDC_JWKS_URL"])!""
                        )
                    )]
                    [#break]
            [/#switch]

            [@createUserPoolAuthProvider
                id=authProviderId
                name=authProviderName
                userPoolId=userPoolId
                providerType=authProviderEngine
                providerDetails=providerDetails
                attributeMappings=attributeMappings
                idpIdentifiers=subSolution.IDPIdentifiers
            /]
        [/#if]

        [#if subCore.Type == USERPOOL_CLIENT_COMPONENT_TYPE]

            [#if subCore.SubComponent.Id = "default" ]
                [#local defaultUserPoolClientConfigured = true]
            [/#if]

            [#local userPoolClientId           = subResources["client"].Id]
            [#local userPoolClientName         = subResources["client"].Name]

            [#local callbackUrls = []]
            [#local logoutUrls = []]
            [#local identityProviders = [ ]]

            [#local clientDepedencies = []]

            [#local oAuthScopes = subSolution.OAuth.Scopes]

            [#list subSolution.AuthProviders as authProvider ]
                [#if authProvider?upper_case == "COGNITO" ]
                    [#local identityProviders += [ "COGNITO" ] ]
                [#else]
                    [#local linkTarget = getLinkTarget(
                                                occurrence,
                                                {
                                                    "Tier" : core.Tier.Id,
                                                    "Component" : core.Component.RawId,
                                                    "AuthProvider" : authProvider
                                                },
                                                false
                                            )]
                    [#if linkTarget?has_content && linkTarget.Configuration.Solution.Enabled  ]]
                        [#local identityProviders += [ linkTarget.State.Attributes["PROVIDER_NAME"] ]]
                        [#local clientDepedencies += [ linkTarget.State.Resources["authprovider"].Id ]]
                    [/#if]
                [/#if]
            [/#list]

            [#list subSolution.ResourceScopes as id,resourceScope ]
                [#local linkTarget = getLinkTarget(
                                            occurrence,
                                            {
                                                "Tier" : core.Tier.Id,
                                                "Component" : core.Component.RawId,
                                                "Resource" : resourceScope.Name
                                            },
                                            false
                                        )]
                [#if linkTarget?has_content && linkTarget.Configuration.Solution.Enabled ]]

                    [#local resourceIdentifier = getReference( linkTarget.State.Resources["resourceserver"].Id )  ]

                    [#list linkTarget.State.Resources as id,linkResource ]

                        [@debug message="linkResource"  context=linkResource enabled=true /]
                        [#if linkResource.Type == AWS_COGNITO_USERPOOL_RESOURCESCOPE_RESOURCE_TYPE ]
                            [#if resourceScope.Scopes?seq_contains(linkResource.Name)]

                                [#local oAuthScopes += [{
                                        "Fn::Join": [
                                            "/",
                                            [
                                                resourceIdentifier,
                                                linkResource.Name
                                            ]
                                        ]
                                    }]]
                                [#local clientDepedencies += [ linkTarget.State.Resources["resourceserver"].Id]]
                            [/#if]

                        [/#if]
                    [/#list]
                [/#if]
            [/#list]

            [#list subSolution.Links?values as link]
                [#local linkTarget = getLinkTarget(subOccurrence, link)]

                [@debug message="Link Target" context=linkTarget enabled=false /]

                [#if !linkTarget?has_content]
                    [#continue]
                [/#if]

                [#local linkTargetCore = linkTarget.Core]
                [#local linkTargetConfiguration = linkTarget.Configuration ]
                [#local linkTargetResources = linkTarget.State.Resources]
                [#local linkTargetAttributes = linkTarget.State.Attributes]

                [#switch linkTargetCore.Type]
                    [#case LB_PORT_COMPONENT_TYPE]
                        [#local callbackUrls += [
                            linkTargetAttributes["AUTH_CALLBACK_URL"],
                            linkTargetAttributes["AUTH_CALLBACK_INTERNAL_URL"]
                            ]
                        ]
                        [#break]

                    [#case "external" ]
                    [#case EXTERNALSERVICE_COMPONENT_TYPE ]
                        [#if linkTargetAttributes["AUTH_CALLBACK_URL"]?has_content ]
                            [#local callbackUrls += linkTargetAttributes["AUTH_CALLBACK_URL"]?split(",") ]
                        [/#if]
                        [#if linkTargetAttributes["AUTH_SIGNOUT_URL"]?has_content ]
                            [#local logoutUrls += linkTargetAttributes["AUTH_SIGNOUT_URL"]?split(",") ]
                        [/#if]
                        [#break]

                    [#case USERPOOL_AUTHPROVIDER_COMPONENT_TYPE ]
                        [#if linkTargetConfiguration.Solution.Enabled  ]
                            [#local identityProviders += [ linkTargetAttributes["PROVIDER_NAME"] ] ]
                        [/#if]
                        [#break]
                [/#switch]
            [/#list]

            [#if deploymentSubsetRequired(USERPOOL_COMPONENT_TYPE, true) ]
                [@createUserPoolClient
                    id=userPoolClientId
                    name=userPoolClientName
                    userPoolId=userPoolId
                    generateSecret=subSolution.ClientGenerateSecret
                    tokenValidity=subSolution.ClientTokenValidity
                    oAuthFlows=subSolution.OAuth.Flows
                    oAuthScopes=oAuthScopes
                    oAuthEnabled=true
                    identityProviders=identityProviders
                    callbackUrls=callbackUrls
                    logoutUrls=logoutUrls
                    dependencies=clientDepedencies
                /]
            [/#if]
        [/#if]

        [#if subCore.Type == USERPOOL_RESOURCE_COMPONENT_TYPE ]
            [#local resourceServerId  = subResources["resourceserver"].Id ]
            [#local resourceServerName = subResources["resourceserver"].Name ]

            [#local serverIdentifier = ""]

            [#-- determine the server id using links --]
            [#local linkTarget = getLinkTarget(subOccurrence, subSolution.Server.Link )]
            [@debug message="Link Target" context=linkTarget enabled=false /]

            [#if !linkTarget?has_content]
                [#continue]
            [/#if]

            [#local linkTargetAttributes = linkTarget.State.Attributes]

            [#if ((linkTargetAttributes[subSolution.Server.LinkAttribute])!"")?has_content ]
                [#local serverIdentifier = linkTargetAttributes[subSolution.Server.LinkAttribute] ]
            [#else]
                [@fatal
                    message="Server Link Attribute not found"
                    context=subSolution.Server
                    detail="The LinkAttribute specified could not be found on the provided link"
                /]
            [/#if]

            [#-- build userpool resource scopes --]
            [#local resourceScopes = []]
            [#list subSolution.Scopes as id,scope ]
                [#local resourceScopes +=
                    [ getUserPoolResourceScope(scope.Name, scope.Description ) ]]
            [/#list]

            [@createUserPoolResourceServer
                id=resourceServerId
                name=resourceServerName
                identifier=serverIdentifier
                userPoolId=userPoolId
                scopes=resourceScopes
            /]
        [/#if]
    [/#list]

    [#if defaultUserPoolClientRequired && ! defaultUserPoolClientConfigured ]
            [@fatal
                message="A default userpool client is required"
                context=solution
                detail={
                    "ActionOptions" : {
                        "1" : "Add a Client to the userpool with the id default and copy any client configuration to it",
                        "2" : "Decommission the use of the legacy client and disable DefaultClient in the solution config"
                    },
                    "context" : {
                        "DefaultClient" : defaultUserPoolClientId,
                        "DefaultClientId" : getExistingReference(defaultUserPoolClientId)
                    },
                    "Configuration" : {
                        "Clients" : {
                            "default" : {
                            }
                        }
                    }
                }
            /]
    [/#if]

    [#if deploymentSubsetRequired(USERPOOL_COMPONENT_TYPE, true) ]
        [@createUserPool
            component=core.Component
            tier=core.Tier
            id=userPoolId
            name=userPoolName
            tags=getOccurrenceCoreTags(occurrence, userPoolName)
            mfa=mfaConfig
            mfaMethods=solution.MFAMethods
            usernameConfig=solution.Username
            userDeviceTracking=deviceTrackingConfig
            userActivityTracking=solution.Security.ActivityTracking
            adminCreatesUser=solution.AdminCreatesUser
            schema=schema
            emailVerificationMessage=emailVerificationMessage
            emailVerificationSubject=emailVerificationSubject
            smsVerificationMessage=smsVerificationMessage
            smsAuthenticationMessage=smsAuthenticationMessage
            smsInviteMessage=smsInviteMessage
            emailInviteMessage=emailInviteMessage
            emailInviteSubject=emailInviteSubject
            lambdaTriggers=userPoolTriggerConfig
            autoVerify=(solution.VerifyEmail || smsVerification)?then(
                getUserPoolAutoVerification(solution.VerifyEmail, smsVerification),
                []
            )
            loginAliases=loginAliases
            passwordPolicy=getUserPoolPasswordPolicy(
                    solution.PasswordPolicy.MinimumLength,
                    solution.PasswordPolicy.Lowercase,
                    solution.PasswordPolicy.Uppsercase,
                    solution.PasswordPolicy.Numbers,
                    solution.PasswordPolicy.SpecialCharacters,
                    solution.UnusedAccountTimeout)
            userAccountRecovery=solution.PasswordPolicy.AllowUserRecovery
            smsConfiguration=smsConfig
        /]

        [@createUserPoolDomain
            id=userPoolDomainId
            userPoolId=userPoolId
            domainName=userPoolHostName
            customDomain=false
        /]

        [#if customDomainRequired ]
            [@createUserPoolDomain
                id=userPoolCustomDomainId
                userPoolId=userPoolId
                domainName=userPoolCustomDomainName
                customDomain=true
                certificateArn=userPoolCustomDomainCertArn
            /]
        [/#if]

    [/#if]
[/#macro]
