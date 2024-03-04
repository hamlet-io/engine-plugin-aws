[#ftl]
[#macro aws_user_cf_deployment_generationcontract_application occurrence ]
    [@addDefaultGenerationContract subsets=["deploymentcontract", "prologue", "template", "epilogue"] /]
[/#macro]

[#macro aws_user_cf_deployment_deploymentcontract occurrence ]
    [@addDefaultAWSDeploymentContract prologue=true epilogue=true /]
[/#macro]

[#macro aws_user_cf_deployment_application occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local resources = occurrence.State.Resources]
    [#local solution = occurrence.Configuration.Solution ]

    [#local userId = resources["user"].Id ]
    [#local userName = resources["user"].Name]
    [#local apikeyId = resources["apikey"].Id ]
    [#local apikeyName = resources["apikey"].Name]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "OpsData", "AppData", "Encryption" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local operationsBucket = getExistingReference(baselineComponentIds["OpsData"]) ]
    [#local cmkKeyId = baselineComponentIds["Encryption"] ]
    [#local cmkKeyArn = getExistingReference(cmkKeyId, ARN_ATTRIBUTE_TYPE)]

    [#local credentialFormats = solution.GenerateCredentials.Formats]
    [#local userPasswordLength = solution.GenerateCredentials.CharacterLength ]

    [#local managedPolicyArns = []]

    [#local fileTransferUser = false ]
    [#if (resources["transferRole"]!{})?has_content]
        [#local fileTransferUser = true]
        [#local transferRoleId = resources["transferRole"].Id ]
    [/#if]

    [#local passwordEncryptionScheme = (solution.GenerateCredentials.EncryptionScheme?has_content)?then(
        solution.GenerateCredentials.EncryptionScheme?ensure_ends_with(":"),
        "" )]

    [#local encryptedSystemPassword = (
        getExistingReference(
            userId,
            PASSWORD_ATTRIBUTE_TYPE)
        )?remove_beginning(
            passwordEncryptionScheme
        )]

    [#local encryptedConsolePassword = (
        getExistingReference(
            userId,
            GENERATEDPASSWORD_ATTRIBUTE_TYPE)
        )?remove_beginning(
            passwordEncryptionScheme
        )]

        [#local sourceCidr = getGroupCIDRs(solution.IPAddressGroups) ]

    [#-- Add in container specifics including override of defaults --]
    [#-- Allows for explicit policy or managed ARN's to be assigned to the user --]
    [#local contextLinks = getLinkTargets(occurrence) ]
    [#local _context =
        {
            "DefaultEnvironment" : defaultEnvironment(occurrence, contextLinks, baselineLinks),
            "Environment" : {},
            "Links" : contextLinks,
            "DefaultCoreVariables" : false,
            "DefaultEnvironmentVariables" : false,
            "DefaultLinkVariables" : false,
            "Policy" :
                iamStandardPolicies(occurrence, baselineComponentIds) +
                valueIfContent(
                    [
                        getPolicyStatement(
                            "*",
                            "*",
                            "",
                            getIPCondition(sourceCidr, false),
                            false
                        )
                    ],
                    sourceCidr,
                    []
                ),
            "TransferMounts" : {}
        }
    ]

    [#-- Add in extension specifics including override of defaults --]
    [#local _context = invokeExtensions( occurrence, _context )]

    [#local sshPublicKeys = {}]
    [#list solution.SSHPublicKeys as id,publicKey ]
        [#if (_context.DefaultEnvironment[publicKey.SettingName])?has_content ]
            [#local sshPublicKeys = mergeObjects(sshPublicKeys, { id : _context.DefaultEnvironment[publicKey.SettingName] }) ]
        [/#if]
    [/#list]

    [#if deploymentSubsetRequired("prologue", false)]
        [@addToDefaultBashScriptOutput
            content=
            [
                "case $\{STACK_OPERATION} in",
                "  delete)",
                "   manage_iam_userpassword" +
                "   \"" + getRegion() + "\" " +
                "   \"delete\" " +
                "   \"" + userName + "\" || return $?",
                "   ;;",
                "esac"
            ]
        /]
        [#-- Copy any asFiles  --]
        [#local asFiles = getAsFileSettings(occurrence.Configuration.Settings.Product) ]
        [#if asFiles?has_content]
            [@debug message="Asfiles" context=asFiles enabled=false /]
            [@addToDefaultBashScriptOutput
                content=
                    findAsFilesScript("filesToSync", asFiles) +
                    syncFilesToBucketScript(
                        "filesToSync",
                        getRegion(),
                        operationsBucket,
                        getOccurrenceSettingValue(occurrence, "SETTINGS_PREFIX")
                    ) /]
        [/#if]
    [/#if]

    [#if fileTransferUser]
        [#if deploymentSubsetRequired("iam", true) &&
                isPartOfCurrentDeploymentUnit(transferRoleId)]

            [#local transferPolicySet = {}]

            [#-- Managed Policies --]
            [#local transferPolicySet =
                addAWSManagedPoliciesToSet(
                    transferPolicySet,
                    _context.ManagedPolicy
                )
            ]

            [#local transferPolicySet =
                addInlinePolicyToSet(
                    transferPolicySet,
                    formatDependentPolicyId(occurrence.Core.Id, "transfer", _context.Name),
                    _context.Name,
                    _context.Policy
                )
            ]

            [#local transferLinks = {} ]
            [#list (_context.Links) as id, linkTarget ]
                [#if linkTarget.Core.Type == S3_COMPONENT_TYPE ]
                    [#local transferLinks = mergeObjects(transferLinks, { id, linkTarget}) ]
                [/#if]
            [/#list]

            [#local transferLinkPolicies = getLinkTargetsOutboundRoles(transferLinks)]

            [#-- Any permissions granted via links --]
            [#local transferPolicySet =
                addInlinePolicyToSet(
                    transferPolicySet,
                    formatDependentPolicyId(occurrence.Core.Id, "transfer", "links"),
                    "links",
                    getLinkTargetsOutboundRoles(transferLinks)
                )
            ]

            [#-- Ensure we don't blow any limits as far as possible --]
            [#local transferPolicySet = adjustPolicySetForRole(transferPolicySet) ]

            [#-- Create any required managed policies --]
            [#-- They may result when policies are split to keep below AWS limits --]
            [@createCustomerManagedPoliciesFromSet policies=transferPolicySet /]

            [@createRole
                id=transferRoleId
                trustedServices=["transfer.amazonaws.com" ]
                managedArns=getManagedPoliciesFromSet(transferPolicySet)
                tags=getOccurrenceTags(occurrence)
            /]

            [#-- Create any inline policies that attach to the role --]
            [@createInlinePoliciesFromSet policies=transferPolicySet roles=transferRoleId /]
        [/#if]
    [/#if]

    [#local policySet = {}]

    [#if deploymentSubsetRequired(USER_COMPONENT_TYPE, true)]

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
                formatDependentPolicyId(occurrence.Core.Id, _context.Name),
                _context.Name,
                _context.Policy
            )
        ]

        [#-- Any permissions granted via links --]
        [#local policySet =
            addInlinePolicyToSet(
                policySet,
                formatDependentPolicyId(occurrence.Core.Id, "links"),
                "links",
                getLinkTargetsOutboundRoles(_context.Links)
            )
        ]

        [#-- Ensure we don't blow any limits as far as possible --]
        [#local policySet = adjustPolicySetForRole(policySet) ]

        [#-- Create any required managed policies --]
        [#-- They may result when policies are split to keep below AWS limits --]
        [@createCustomerManagedPoliciesFromSet policies=policySet /]

        [@cfResource
            id=userId
            type="AWS::IAM::User"
            properties=
                {
                    "UserName" : userName
                } +
                attributeIfContent(
                    "ManagedPolicyArns",
                    getManagedPoliciesFromSet(policySet)
                ) +
                attributeIfContent(
                    "PermissionsBoundary",
                    (solution["aws:PermissionsBoundaryPolicyArn"])!""
                )
            outputs=USER_OUTPUT_MAPPINGS
            tags=getOccurrenceTags(occurrence)
        /]

        [#-- Create any inline policies that attach to the role --]
        [@createInlinePoliciesFromSet policies=policySet users=userId /]

        [#-- Manage API keys for the user if linked to usage plans --]
        [#local apikeyNeeded = false ]
        [#local transferRoleRequired = false ]

        [#list solution.Links?values as link]
            [#if link?is_hash]
                [#local linkTarget = getLinkTarget(occurrence, link, false) ]

                [@debug message="Link Target" context=linkTarget enabled=false /]

                [#if !linkTarget?has_content]
                    [#continue]
                [/#if]

                [#local linkTargetResources = linkTarget.State.Resources ]
                [#local linkTargetAttributes = linkTarget.State.Attributes ]

                [#switch linkTarget.Core.Type]
                    [#case APIGATEWAY_USAGEPLAN_COMPONENT_TYPE ]
                        [#if isLinkTargetActive(linkTarget) ]
                            [@createAPIUsagePlanMember
                                id=formatDependentResourceId(AWS_APIGATEWAY_USAGEPLAN_MEMBER_RESOURCE_TYPE, apikeyId, link.Id)
                                planId=linkTargetResources["apiusageplan"].Id
                                apikeyId=apikeyId
                            /]
                        [/#if]
                        [#local apikeyNeeded = true]
                        [#break]

                    [#case FILETRANSFER_COMPONENT_TYPE ]
                        [#if isLinkTargetActive(linkTarget) ]

                            [#if ! sshPublicKeys?has_content ]
                                [@fatal
                                    message="No Public SSH Keys found"
                                    detail="Add an SSH Key to this user using the SSHPublicKeys Configuration"
                                    context={
                                        "SSHPublicKeys" : solution.SSHPublicKeys
                                    }
                                /]
                            [/#if]

                            [#if ! (_context.TransferMounts)?has_content ]
                                [@fatal
                                    message="No Tranfer Mount Locations found"
                                    detail="Add at least one transfer mount using the userTransferMount extension macro"
                                /]
                            [/#if]

                            [@createTransferUser
                                id=resources["transferUsers"][link.Id].Id
                                username=resources["transferUsers"][link.Id].UserName
                                homeDirectoryMappings=_context.TransferMounts?values
                                roleId=resources["transferRole"].Id
                                transferServerId=linkTargetResources["transferserver"].Id
                                sshPublicKeys=sshPublicKeys?values
                                tags=getOccurrenceTags(occurrence)
                            /]
                        [/#if]
                        [#break]
                [/#switch]
            [/#if]
        [/#list]
        [#if apikeyNeeded ]
            [@createAPIKey
                id=apikeyId
                name=apikeyName
                tags=getOccurrenceTags(occurrence)
            /]
        [/#if]
    [/#if]

    [#if deploymentSubsetRequired("epilogue", false)]
        [@addToDefaultBashScriptOutput
            content=
            [
                "case $\{STACK_OPERATION} in",
                "  create|update)"
            ] +
            ( credentialFormats?seq_contains("system") && !(encryptedSystemPassword?has_content))?then(
                [
                    r'# Generate IAM AccessKey',
                    r'function generate_iam_accesskey() {',
                    r'  info "Generating IAM AccessKey"',
                    r'  IFS=" " read -r -a access_key_pair <<< "$(create_iam_accesskey "' + getRegion() + r'" "' + userName + r'" || return $?)"',
                    r'  encrypted_secret_key="$(encrypt_kms_string "' + getRegion() + r'" "${access_key_pair[1]}" "' + cmkKeyArn + r'" || return $?)"'
                ] +
                pseudoStackOutputScript(
                    "IAM User AccessKey",
                    {
                        formatId(userId, "username") : r'${access_key_pair[0]}',
                        formatId(userId, "password") : r'${encrypted_secret_key}'
                    },
                    formatName(userName, "system-creds")
                ) +
                [
                    r'}',
                    r'generate_iam_accesskey || return $?'
                ],
                []) +
            ( credentialFormats?seq_contains("console") && !(encryptedConsolePassword?has_content) )?then(
                [
                    r'# Generate User Password',
                    r'function generate_user_password() {',
                    r'  info "Generating User Password"',
                    r'  user_password="$(generateComplexString "' + userPasswordLength + r'" )"',
                    r'  encrypted_user_password="$(encrypt_kms_string "' + getRegion() + r'" "${user_password}" "' + cmkKeyArn + r'" || return $?)"',
                    r'  info "Setting User Password"',
                    r'  manage_iam_userpassword "' + getRegion() + r'" "manage" "' + userName + r'" "${user_password}" || return $?'
                ] +
                pseudoStackOutputScript(
                    "IAM User Password",
                    {
                        formatId(userId, "generatedpassword") : r'${encrypted_user_password}'
                    },
                    formatName(userName, "console-creds")
                ) +
                [
                    r'}',
                    r'generate_user_password || return $?'
                ],
            []) +
            [
                r'       ;;',
                r'       esac'
            ]
        /]
    [/#if]
[/#macro]
