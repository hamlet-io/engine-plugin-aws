[#ftl]

[#assign USERPOOL_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        NAME_ATTRIBUTE_TYPE : {
            "Attribute" : "ProviderName"
        },
        ARN_ATTRIBUTE_TYPE : {
            "Attribute" : "Arn"
        },
        URL_ATTRIBUTE_TYPE : {
            "Attribute" : "ProviderURL"
        },
        REGION_ATTRIBUTE_TYPE: {
            "Value" : { "Ref" : "AWS::Region" }
        }
    }
]

[#assign USERPOOL_CLIENT_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[#assign USERPOOL_AUTHPROVIDER_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[#assign USERPOOL_DOMAIN_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]

[#assign USERPOOL_RESOURCESERVER_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }

]

[#assign IDENTITYPOOL_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        NAME_ATTRIBUTE_TYPE : {
            "Attribute" : "Name"
        }
    }
]

[#assign cogniitoMappings =
    {
        AWS_COGNITO_USERPOOL_RESOURCE_TYPE : USERPOOL_OUTPUT_MAPPINGS,
        AWS_COGNITO_USERPOOL_CLIENT_RESOURCE_TYPE : USERPOOL_CLIENT_OUTPUT_MAPPINGS,
        AWS_COGNITO_USERPOOL_AUTHPROVIDER_RESOURCE_TYPE: USERPOOL_AUTHPROVIDER_OUTPUT_MAPPINGS,
        AWS_COGNITO_USERPOOL_DOMAIN_RESOURCE_TYPE : USERPOOL_DOMAIN_OUTPUT_MAPPINGS,
        AWS_COGNITO_USERPOOL_RESOURCESERVER_RESOURCE_TYPE : USERPOOL_RESOURCESERVER_OUTPUT_MAPPINGS,
        AWS_COGNITO_IDENTITYPOOL_RESOURCE_TYPE : IDENTITYPOOL_OUTPUT_MAPPINGS
    }
]

[#list cogniitoMappings as type, mappings]
    [@addOutputMapping
        provider=AWS_PROVIDER
        resourceType=type
        mappings=mappings
    /]
[/#list]

[#function getUserPoolPasswordPolicy length="8" lowercase=true uppercase=true numbers=true symbols=true tempPasswordValidity=30 ]
    [#return
        {
            "PasswordPolicy" : {
                "MinimumLength"     : length,
                "RequireLowercase"  : lowercase,
                "RequireUppercase"  : uppercase,
                "RequireNumbers"    : numbers,
                "RequireSymbols"    : symbols,
                "TemporaryPasswordValidityDays" : tempPasswordValidity
            }
        }
    ]
[/#function]

[#function getUserPoolSMSConfiguration snsId externalId ]
    [#return
        {
            "SnsCallerArn" : snsId,
            "ExternalId" : externalId
        }
    ]
[/#function]

[#function getUserPoolSchemaObject name datatype mutable required constraints ]

    [#local schema =
        {
            "Name" : name,
            "AttributeDataType" : datatype,
            "Mutable" : mutable,
            "Required" : required
        }]

    [#switch datatype?lower_case ]
        [#case "string"]

            [#if constraints.String.MinLength > 0 ]
                [#local schema += {
                    "StringAttributeConstraints" : {
                        "MinLength" : (constraints.String.MinLength)?c
                    }
                }]
            [/#if]

            [#if constraints.String.MaxLength > 0 ]
                [#local schema += {
                    "StringAttributeConstraints" : {
                        "MaxLength" : (constraints.String.MaxLength)?c
                    }
                }]
            [/#if]
            [#break]

        [#case "number"]
            [#if ((constraints.Number.MinValue)!"")?has_content ]
                [#local schema += {
                    "StringAttributeConstraints" : {
                        "MinValue" : (constraints.Number.MinValue)?c
                    }
                }]
            [/#if]

            [#if ((constraints.Number.MaxValue)!"")?has_content ]
                [#local schema += {
                    "StringAttributeConstraints" : {
                        "MaxValue" : (constraints.Number.MaxValue)?c
                    }
                }]
            [/#if]
            [#break]

        [#default]
            [@fatal
                message="Unexpected data type for cognito userpool schema attribute constraints"
                context=datatype
            /]
            [#break]
    [/#switch]

    [#return
        [
            schema
        ]
    ]
[/#function]

[#function getUserPoolAutoVerification email=false phone=false ]
    [#assign autoVerifyArray=[]]

    [#if email ]
        [#assign autoVerifyArray = autoVerifyArray + [ "email" ] ]
    [/#if]

    [#if phone ]
        [#assign autoVerifyArray = autoVerifyArray + [ "phone_number" ]]
    [/#if]

    [#return
        autoVerifyArray
    ]
[/#function]

[#function getUserPoolInviteMessageTemplate emailMessage="" emailSubject="" smsMessage="" ]
    [#return
        {} +
        attributeIfContent(
            "EmailMessage",
            emailMessage
        ) +
        attributeIfContent(
            "EmailSubject",
            emailSubject
        ) +
        attributeIfContent(
            "SMSMessage",
            smsMessage
        )
    ]
[/#function]

[#function getUserPoolAdminCreateUserConfig enabled inviteMessageTemplate={} ]
    [#return
        {
            "AllowAdminCreateUserOnly" : enabled
        }   +
            attributeIfContent(
                "InviteMessageTemplate",
                inviteMessageTemplate
            )
    ]
[/#function]

[#function getIdentityPoolCognitoProvider userPool userPoolClient ]

    [#return
        [
            {
                "ProviderName" : userPool,
                "ClientId" : userPoolClient,
                "ServerSideTokenCheck" : true
            }
        ]
    ]
[/#function]


[#function getIdentityPoolMappingRule priority claim matchType value roleId ]
    [#return
        [
            {
                "Priority" : priority,
                "Rule" :  {
                    "Claim" : claim,
                    "MatchType" : matchType,
                    "RoleARN" : getArn( roleId ),
                    "Value" : value
                }
            }

        ]
    ]
[/#function]

[#function getIdentityPoolRoleMapping provider mappingType mappingRules matchBehaviour ]

    [#switch matchBehaviour ]
        [#case "UseAuthenticatedRule" ]
            [#local matchBehaviour = "AuthenticatedRole"]
            [#break]
        [#default]
            [#local matchBehaviour = "Deny" ]
    [/#switch]

    [#return
        {
            provider : {
                "AmbiguousRoleResolution" : matchBehaviour,
                "RulesConfiguration" : {
                    "Rules" : mappingRules
                },
                "Type" : mappingType
            }
        }
    ]
[/#function]

[#function getUserPoolVerificationMessageTemplate
    verificationEmailType
    emailVerificationMessage
    emailVerificationSubject
    emailVerificationMessageByLink
    emailVerificationSubjectByLink
    smsVerificationMessage
]
    [#assign defaultEmailOption = ""]
    [#if verificationEmailType == "code" ]
        [#assign defaultEmailOption = "CONFIRM_WITH_CODE"]
    [#elseif verificationEmailType == "link" ]
        [#assign defaultEmailOption = "CONFIRM_WITH_LINK"]
    [/#if]

    [#return
        {} +
        attributeIfContent(
            "DefaultEmailOption",
            defaultEmailOption
        ) +
        attributeIfContent(
            "EmailMessage",
            emailVerificationMessage
        ) +
        attributeIfContent(
            "EmailSubject",
            emailVerificationSubject
        ) +
        attributeIfContent(
            "EmailMessageByLink",
            emailVerificationMessageByLink
        ) +
        attributeIfContent(
            "EmailSubjectByLink",
            emailVerificationSubjectByLink
        ) +
        attributeIfContent(
            "SmsMessage",
            smsVerificationMessage
        )
    ]
[/#function]

[#function getUserPoolEmailConfiguration fromId from replyTo="" ]
    [#return
        {
            "EmailSendingAccount" : "DEVELOPER",
            "SourceArn" : getArn(fromId),
            "From" : from
        } +
        attributeIfContent(
            "ReployToEmailAddress",
            replyTo
        )
    ]
[/#function]

[#macro createUserPool id
    name
    mfa
    adminCreatesUser
    userDeviceTracking={}
    userActivityTracking=""
    userAccountRecovery=true
    usernameConfig={}
    smsVerificationMessage=""
    emailVerificationMessage=""
    emailVerificationSubject=""
    emailConfiguration={}
    verificationMessageTemplate={}
    smsInviteMessage=""
    emailInviteMessage=""
    emailInviteSubject=""
    smsAuthenticationMessage=""
    mfaMethods=[]
    loginAliases=[]
    autoVerify=[]
    schema=[]
    smsConfiguration={}
    passwordPolicy={}
    lambdaTriggers={}
    dependencies=""
    outputId=""
    tags={}
]

    [#local enabledMfas = []]
    [#list mfaMethods as mfaMethod ]
        [#switch mfaMethod ]
            [#case "SMS" ]
                [#local enabledMfas = combineEntities(
                                            enabledMfas,
                                            "SMS_MFA",
                                            UNIQUE_COMBINE_BEHAVIOUR
                )]
                [#break]

            [#case "SoftwareToken" ]
                [#local enabledMfas = combineEntities(
                                            enabledMfas,
                                            "SOFTWARE_TOKEN_MFA",
                                            UNIQUE_COMBINE_BEHAVIOUR
                )]
                [#break]
        [/#switch]
    [/#list]

    [#local accountRecoveryMethods = []]

    [#if userAccountRecovery ]
        [#list schema as value ]
            [#if value.Name == "email" ]
                [#local accountRecoveryMethods += [
                     {
                        "Name" : "verified_email",
                        "Priority" : 1
                    }]]
            [/#if]

            [#if value.Name == "phone_number" && ! mfaMethods?seq_contains("SMS") ]
                [#local accountRecoveryMethods += [
                     {
                        "Name" : "verified_phone_number",
                        "Priority" : 2
                    }]]
            [/#if]
        [/#list]
    [#else]
        [#local accountRecoveryMethods += [
            {
                "Name" : "admin_only",
                "Priority" : 1
            }
        ]]

    [/#if]

    [@cfResource
        id=id
        type="AWS::Cognito::UserPool"
        properties=
            {
                "UserPoolName" : name,
                "MfaConfiguration" : mfa,
                "AdminCreateUserConfig" :
                    getUserPoolAdminCreateUserConfig(
                        adminCreatesUser,
                        getUserPoolInviteMessageTemplate(
                            emailInviteMessage,
                            emailInviteSubject,
                            smsInviteMessage)),
                "AccountRecoverySetting" : {
                    "RecoveryMechanisms" : accountRecoveryMethods
                },
                "UserPoolAddOns" : {
                    "AdvancedSecurityMode" :
                            ( userActivityTracking == "disabled" )?then(
                                "OFF",
                                userActivityTracking?upper_case
                            )
                }
            } +
            attributeIfContent(
                "Policies",
                passwordPolicy
            ) +
            attributeIfContent(
                "AliasAttributes",
                loginAliases
            ) +
            attributeIfContent(
                "AutoVerifiedAttributes",
                autoVerify
            ) +
            attributeIfContent(
                "SmsConfiguration",
                smsConfiguration
            ) +
            attributeIfContent(
                "Schema",
                schema
            ) +
            attributeIfContent (
                "EmailVerificationMessage"
                emailVerificationMessage
            ) +
            attributeIfContent (
                "EmailVerificationSubject",
                emailVerificationSubject
             ) +
            attributeIfContent (
                "EmailConfiguration",
                emailConfiguration
             ) +
             attributeIfContent (
                "SmsVerificationMessage",
                smsVerificationMessage
             ) +
             attributeIfContent(
                 "SmsAuthenticationMessage",
                 smsAuthenticationMessage
             ) +
             attributeIfContent (
                "LambdaConfig",
                lambdaTriggers
             ) +
             attributeIfTrue(
                "EnabledMfas",
                ( mfa == "OPTIONAL" || mfa == "ON" ),
                enabledMfas
             ) +
             attributeIfTrue(
                "UsernameConfiguration",
                ( ! usernameConfig.CaseSensitive ),
                {
                    "CaseSensitive" : usernameConfig.CaseSensitive
                }
             ) +
             attributeIfContent(
                "UsernameAttributes",
                usernameConfig.Attributes
             ) +
             attributeIfContent(
                 "DeviceConfiguration",
                 userDeviceTracking
             ) +
             attributeIfContent(
                 "VerificationMessageTemplate",
                 verificationMessageTemplate
             ) +
             attributeIfContent(
                "UserPoolTags",
                tags,
                getCFResourceTags(tags, true)
             )
        outputs=USERPOOL_OUTPUT_MAPPINGS
        outputId=outputId
        dependencies=dependencies
    /]
[/#macro]

[#macro createUserPoolClient id name
        userPoolId
        generateSecret=false
        tokenValidity=30
        oAuthFlows=[]
        oAuthScopes=[]
        oAuthEnabled=true
        identityProviders=[]
        callbackUrls=[]
        logoutUrls=[]
        dependencies=""
        outputId=""
]

    [@cfResource
        id=id
        type="AWS::Cognito::UserPoolClient"
        properties=
            {
                "ClientName" : name,
                "GenerateSecret" : generateSecret,
                "RefreshTokenValidity" : tokenValidity,
                "UserPoolId" : getReference(userPoolId),
                "AllowedOAuthFlowsUserPoolClient" : oAuthEnabled,
                "PreventUserExistenceErrors" : "ENABLED"
            } +
            oAuthEnabled?then(
                {} +
                attributeIfContent(
                    "AllowedOAuthFlows",
                    oAuthFlows
                ) +
                attributeIfContent(
                    "AllowedOAuthScopes",
                    oAuthScopes
                ),
                {}
            ) +
            attributeIfContent(
                "SupportedIdentityProviders",
                identityProviders
            ) +
            attributeIfContent(
                "CallbackURLs",
                callbackUrls
            ) +
            attributeIfContent(
                "LogoutURLs",
                logoutUrls
            )
        outputs=USERPOOL_CLIENT_OUTPUT_MAPPINGS
        outputId=outputId
        dependencies=dependencies
    /]
[/#macro]


[#macro createUserPoolAuthProvider id name
        userPoolId
        providerType
        providerDetails
        attributeMappings={}
        idpIdentifiers=[]
        dependencies=""
        outputId=""
 ]

    [#-- override some of the providers which use longer names --]
    [#switch providerType ]
        [#case "Amazon" ]
            [#local providerType = "LoginWithAmazon" ]
            [#break]
        [#case "Apple"]
            [#local providerType = "SignInWithApple" ]
            [#break]
    [/#switch]

    [@cfResource
        id=id
        type="AWS::Cognito::UserPoolIdentityProvider"
        properties={
            "ProviderName" : name,
            "ProviderType" : providerType,
            "UserPoolId" : getReference(userPoolId),
            "ProviderDetails" : providerDetails
        } +
        attributeIfContent(
            "IdpIdentifiers",
            idpIdentifiers
        ) +
        attributeIfContent(
            "AttributeMapping",
            attributeMappings
        )

        outputs=USERPOOL_AUTHPROVIDER_OUTPUT_MAPPINGS
        outputId=outputId
        dependencies=dependencies
    /]
[/#macro]

[#macro createUserPoolDomain id
        userPoolId
        domainName
        customDomain=false
        certificateArn=""
        dependencies=""
        outputId=""
 ]
    [@cfResource
        id=id
        type="AWS::Cognito::UserPoolDomain"
        properties={
            "UserPoolId" : getReference(userPoolId),
            "Domain" : domainName
        } +
        attributeIfTrue(
            "CustomDomainConfig",
            customDomain,
            {
                "CertificateArn" : certificateArn
            }
        )
        outputs=USERPOOL_DOMAIN_OUTPUT_MAPPINGS
        outputId=outputId
        dependencies=dependencies
    /]
[/#macro]


[#function getUserPoolResourceScope name description ]
    [#return
        {
            "ScopeName" : name,
            "ScopeDescription" : description
        }
    ]
[/#function]

[#macro createUserPoolResourceServer id name
    identifier
    userPoolId
    scopes=[]
    dependencies=""
    outputId=""
]
    [@cfResource
        id=id
        type="AWS::Cognito::UserPoolResourceServer"
        properties={
            "Identifier" : identifier,
            "UserPoolId" : getReference(userPoolId),
            "Name" : name,
            "Scopes" : scopes
        }
        outputs=USERPOOL_RESOURCESERVER_OUTPUT_MAPPINGS
        outputId=outputId
        dependencies=dependencies
    /]
[/#macro]

[#macro createIdentityPool id name
    cognitoIdProviders
    allowUnauthenticatedIdentities=false
    tier=""
    component=""
    dependencies=""
    outputId=""
]

    [@cfResource
       id=id
        type="AWS::Cognito::IdentityPool"
        properties=
            {
                "IdentityPoolName" : name,
                "AllowUnauthenticatedIdentities" : allowUnauthenticatedIdentities,
                "CognitoIdentityProviders" : asArray(cognitoIdProviders)
            }
        outputs=USERPOOL_IDENTITY_POOL_OUTPUT_MAPPINGS
        outputId=outputId
        dependencies=dependencies
    /]
[/#macro]

[#macro createIdentityPoolRoleMapping id
    identityPoolId,
    roleMappings={},
    authenticatedRoleId="",
    unauthenticatedRoleId="",
    dependencies=""
    outputId=""
]
    [@cfResource
        id=id
        type="AWS::Cognito::IdentityPoolRoleAttachment"
        properties=
            {
                "IdentityPoolId" : getReference(identityPoolId)
            } +
            attributeIfTrue(
                "Roles",
                ( authenticatedRoleId?has_content || unauthenticatedRoleId?has_content ),
                {} +
                attributeIfContent(
                    "authenticated",
                    getArn(authenticatedRoleId)
                ) +
                attributeIfContent(
                    "unauthenticated",
                    getArn(unauthenticatedRoleId)
                )
            ) +
            attributeIfContent(
                "RoleMappings",
                roleMappings
            )
        outputId=outputId
        dependencies=dependencies
    /]
[/#macro]
