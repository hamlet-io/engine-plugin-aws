[#ftl]
[#macro aws_baseline_cf_deployment_generationcontract_segment occurrence ]
    [@addDefaultGenerationContract subsets=["prologue", "template", "epilogue"] /]
[/#macro]

[#macro aws_baseline_cf_deployment_segment occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]

    [#-- make sure we only have one occurrence --]
    [#if  ! ( core.Tier.Id == "mgmt" &&
            core.Component.Id == "baseline" &&
            core.Version.Id == "" &&
            core.Instance.Id == "" ) ]

        [@fatal
            message="The baseline component can only be deployed once as an unversioned component"
            context=core
        /]
        [#return ]
    [/#if]

    [#-- Segment Seed --]
    [#local segmentSeedId = resources["segmentSeed"].Id ]
    [#if !(getExistingReference(segmentSeedId)?has_content) ]

        [#local segmentSeedValue = resources["segmentSeed"].Value]

        [#if deploymentSubsetRequired("prologue", false)]
            [@addToDefaultBashScriptOutput
                content=
                [
                    "case $\{STACK_OPERATION} in",
                    "  create|update)"
                ] +
                pseudoStackOutputScript(
                        "Seed Values",
                        { segmentSeedId : segmentSeedValue },
                        "seed"
                ) +
                [
                    "       ;;",
                    "       esac"
                ]
            /]
        [/#if]
    [/#if]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "Encryption" ], false, false )]

    [#local cmkResources = baselineLinks["Encryption"].State.Resources ]
    [#local cmkId = cmkResources["cmk"].Id ]
    [#local cmkAlias = cmkResources["cmkAlias"].Name ]

    [#-- Subcomponents --]
    [#list (occurrence.Occurrences![])?filter(x -> x.Configuration.Solution.Enabled ) as subOccurrence]

        [#local subCore = subOccurrence.Core ]
        [#local subSolution = subOccurrence.Configuration.Solution ]
        [#local subResources = subOccurrence.State.Resources ]

        [#local replicationEnabled = false]
        [#local replicationConfiguration = {} ]
        [#local replicationBucket = "" ]

        [#-- Storage bucket --]
        [#if subCore.Type == BASELINE_DATA_COMPONENT_TYPE ]
            [#local bucketId = subResources["bucket"].Id ]
            [#local bucketName = subResources["bucket"].Name ]
            [#local bucketPolicyId = subResources["bucketpolicy"].Id ]
            [#local legacyS3 = subResources["bucket"].LegacyS3 ]
            [#local links = getLinkTargets(subOccurrence)]
            [#local versioningEnabled = (subSolution.Replication!{})?has_content?then(true, subSolution.Versioning)]

            [#local replicationRoleId = subResources["role"].Id]
            [#local replicateEncryptedData = subSolution.Encryption.Enabled
                                                && subSolution.Encryption.EncryptionSource == "EncryptionService"]
            [#local replicationCrossAccount = false ]
            [#local replicationDestinationAccountId = "" ]
            [#local replicationExternalPolicy = []]

            [#if ( deploymentSubsetRequired(BASELINE_COMPONENT_TYPE, true) && legacyS3 == false ) ||
                ( deploymentSubsetRequired("s3") && legacyS3 == true) ]

                [#local lifecycleRules = [] ]
                [#list subSolution.Lifecycles?values as lifecycle ]
                    [#local lifecycleRules +=
                        getS3LifecycleRule(lifecycle.Expiration, lifecycle.Offline, lifecycle.Prefix)]
                [/#list]

                [#local notifications = [] ]
                [#local bucketDependencies = [] ]
                [#local cfAccessCanonicalIds = [] ]

                [#-- Backwards compatible support for legacy OAI keys --]
                [#local legacyOAIId = formatDependentCFAccessId(bucketId)]
                [#local legacyOAI =  getExistingReference(legacyOAIId, CANONICAL_ID_ATTRIBUTE_TYPE) ]

                [#if legacyOAI?has_content]
                    [#local cfAccessCanonicalIds += [ legacyOAI ]]
                [/#if]

                [#list subSolution.Notifications as id,notification ]
                    [#if notification?is_hash && notification.Enabled]
                        [#list notification.Links?values as link]
                            [#if link?is_hash]
                                [#local linkTarget = getLinkTarget(subOccurrence, link, false) ]
                                [@debug message="Link Target" context=linkTarget enabled=false /]
                                [#if !linkTarget?has_content]
                                    [#continue]
                                [/#if]

                                [#local linkTargetResources = linkTarget.State.Resources ]

                                [#if isLinkTargetActive(linkTarget) ]

                                    [#local resourceId = "" ]
                                    [#local resourceType = ""]

                                    [#switch linkTarget.Core.Type]
                                        [#case SQS_COMPONENT_TYPE ]
                                            [#local resourceId = linkTargetResources["queue"].Id ]
                                            [#local resourceType = linkTargetResources["queue"].Type ]
                                            [#if ! (notification["aws:QueuePermissionMigration"]) ]
                                                [@fatal
                                                    message="Queue Permissions update required"
                                                    detail=[
                                                        "SQS policies have been migrated to the queue component",
                                                        "For each S3 bucket add an inbound-invoke link from the Queue to the bucket",
                                                        "When this is completed update the configuration of this notification to QueuePermissionMigration : true"
                                                    ]?join(',')
                                                    context=notification
                                                /]
                                            [/#if]
                                            [#break]

                                        [#case LAMBDA_FUNCTION_COMPONENT_TYPE ]
                                            [#local resourceId = linkTargetResources["lambda"].Id ]
                                            [#local resourceType = linkTargetResources["lambda"].Type ]

                                            [#local policyId =
                                                formatS3NotificationPolicyId(
                                                    bucketId,
                                                    resourceId) ]

                                            [#local bucketDependencies += [policyId] ]
                                            [@createLambdaPermission
                                                id=policyId
                                                targetId=resourceId
                                                sourceId=bucketId
                                                sourcePrincipal="s3.amazonaws.com"
                                            /]

                                            [#break]

                                        [#case TOPIC_COMPONENT_TYPE]
                                            [#local resourceId = linkTargetResources["topic"].Id ]
                                            [#local resourceType = linkTargetResources["topic"].Type ]

                                            [#if ! (notification["aws:TopicPermissionMigration"]) ]
                                                [@fatal
                                                    message="Topic Permissions update required"
                                                    detail=[
                                                        "SNS policies have been migrated to the topic component",
                                                        "For each S3 bucket add an inbound-invoke link from the Topic to the bucket",
                                                        "When this is completed update the configuration of this notification to TopicPermissionMigration : true"
                                                    ]?join(',')
                                                    context=notification
                                                /]
                                            [/#if]

                                    [/#switch]

                                    [#list notification.Events as event ]
                                        [#local notifications +=
                                                getS3Notification(resourceId, resourceType, event, notification.Prefix, notification.Suffix) ]
                                    [/#list]
                                [/#if]
                            [/#if]
                        [/#list]
                    [/#if]
                [/#list]

                [#list subSolution.Links?values as link]
                    [#if link?is_hash]
                        [#local linkTarget = getLinkTarget(occurrence, link, false) ]

                        [@debug message="Link Target" context=linkTarget enabled=false /]

                        [#if !linkTarget?has_content]
                            [#continue]
                        [/#if]

                        [#local linkTargetCore = linkTarget.Core ]
                        [#local linkTargetConfiguration = linkTarget.Configuration ]
                        [#local linkTargetResources = linkTarget.State.Resources ]
                        [#local linkTargetAttributes = linkTarget.State.Attributes ]

                        [#switch linkTargetCore.Type]

                            [#case BASELINE_KEY_COMPONENT_TYPE]
                                [#if linkTargetConfiguration.Solution.Engine == "oai" ]
                                    [#local cfAccessCanonicalIds += [ getReference( (linkTargetResources["originAccessId"].Id), CANONICAL_ID_ATTRIBUTE_TYPE )] ]
                                [/#if]
                                [#break]


                            [#case EXTERNALSERVICE_COMPONENT_TYPE ]
                                [#if linkTarget.Role  == "replicadestination" ]
                                    [#local replicationDestinationAccountId = linkTargetAttributes["ACCOUNT_ID"]!"" ]
                                    [#local replicationExternalPolicy +=   s3ReplicaDestinationPermission( linkTargetAttributes["ARN"] ) ]
                                [/#if]

                            [#case BASELINE_DATA_COMPONENT_TYPE]
                            [#case S3_COMPONENT_TYPE]

                                [#switch linkTarget.Role ]
                                    [#case "replicadestination" ]
                                        [#local replicationEnabled = true]
                                        [#if !replicationBucket?has_content ]
                                            [#local replicationBucket = linkTargetAttributes["ARN"]]
                                        [#else]
                                            [@fatal
                                                message="Only one replication destination is supported"
                                                context=links
                                            /]
                                        [/#if]
                                        [#break]
                                [/#switch]
                                [#break]

                        [/#switch]
                    [/#if]
                [/#list]

                [#-- Add Replication Rules --]
                [#if replicationEnabled ]
                    [#-- Only handle data replication after destination bucket exists --]
                    [#if (subSolution.Replication!{})?has_content]
                        [#local replicationRules = [] ]
                        [#list subSolution.Replication.Prefixes as prefix ]
                            [#local replicationRules +=
                                [ getS3ReplicationRule(
                                    replicationBucket,
                                    subSolution.Replication.Enabled,
                                    prefix,
                                    replicateEncryptedData,
                                    cmkId,
                                    replicationDestinationAccountId
                                )]]
                        [/#list]

                        [#local replicationConfiguration =
                            getS3ReplicationConfiguration(replicationRoleId, replicationRules)]

                        [#local replicationLinkPolicies =
                            getLinkTargetsOutboundRoles(links) +
                            replicateEncryptedData?then(
                                s3EncryptionReadPermission(
                                    cmkId,
                                    bucketName,
                                    "*",
                                    getExistingReference(bucketId, REGION_ATTRIBUTE_TYPE)
                                ),
                                []
                                )]

                        [#local replicationRolePolicies =
                                arrayIfContent(
                                    [getPolicyDocument(replicationLinkPolicies, "links")],
                                    replicationLinkPolicies) +
                                arrayIfContent(
                                    getPolicyDocument(
                                        s3ReplicaSourcePermission(bucketId) +
                                        s3ReplicationConfigurationPermission(bucketId),
                                        "replication"),
                                    replicationConfiguration
                                ) +
                                arrayIfContent(
                                    getPolicyDocument(
                                        replicationExternalPolicy,
                                        "externalreplication"
                                    ),
                                    replicationExternalPolicy
                                )]

                        [#if replicationRolePolicies?has_content ]
                            [@createRole
                                id=replicationRoleId
                                trustedServices=["s3.amazonaws.com"]
                                policies=replicationRolePolicies
                                tags=getOccurrenceTags(subOccurrence)
                            /]
                        [/#if]

                    [/#if]
                [/#if]

                [@createS3Bucket
                    id=bucketId
                    name=bucketName
                    versioning=versioningEnabled
                    lifecycleRules=lifecycleRules
                    notifications=notifications
                    encrypted=subSolution.Encryption.Enabled
                    encryptionSource=subSolution.Encryption.EncryptionSource
                    replicationConfiguration=replicationConfiguration
                    kmsKeyId=cmkId
                    dependencies=bucketDependencies
                    tags=getOccurrenceTags(subOccurrence)
                /]

                [#-- role based bucket policies --]
                [#local bucketPolicy = []]
                [#switch subSolution.Role ]
                    [#case "operations" ]

                        [#local bucketPolicy +=
                            s3WritePermission(
                                bucketName,
                                "AWSLogs",
                                "*",
                                {
                                    "AWS": "arn:aws:iam::" + getRegionObject().Accounts["ELB"] + ":root"
                                }
                            ) +
                            s3ReadBucketACLPermission(
                                bucketName,
                                { "Service": "logs." + getRegion() + ".amazonaws.com" }
                            ) +
                            s3WritePermission(
                                bucketName,
                                "",
                                "*",
                                { "Service": "logs." + getRegion() + ".amazonaws.com" },
                                { "StringEquals": { "s3:x-amz-acl": "bucket-owner-full-control" } }
                            ) +
                            valueIfContent(
                                s3ReadPermission(
                                    bucketName,
                                    formatSegmentPrefixPath("settings"),
                                    "*",
                                    {
                                        "CanonicalUser": cfAccessCanonicalIds
                                    }
                                ) +
                                s3ListPermission(
                                    bucketName,
                                    formatSegmentPrefixPath("settings"),
                                    "*",
                                    {
                                        "CanonicalUser": cfAccessCanonicalIds
                                    }
                                ),
                                cfAccessCanonicalIds,
                                []
                            )
                        ]
                        [#break]
                    [#case "appdata" ]
                        [#if dataPublicEnabled ]

                            [#local dataPublicWhitelistCondition =
                                getIPCondition(getGroupCIDRs(dataPublicIPAddressGroups, true)) ]

                            [#local bucketPolicy += s3ReadPermission(
                                        bucketName,
                                        formatSegmentPrefixPath("apppublic"),
                                        "*",
                                        "*",
                                        dataPublicWhitelistCondition
                                    )]
                        [/#if]
                        [#break]
                [/#switch]

                [#if bucketPolicy?has_content ]
                    [@createBucketPolicy
                        id=bucketPolicyId
                        bucketId=bucketId
                        statements=bucketPolicy
                    /]
                [/#if]
            [/#if]
        [/#if]

        [#-- Access Keys --]
        [#if subCore.Type == BASELINE_KEY_COMPONENT_TYPE ]

            [#local contextLinks = getLinkTargets(subOccurrence) ]

            [#switch subSolution.Engine ]
                [#case "cmk" ]

                    [#local legacyCmk = subResources["cmk"].LegacyKey]
                    [#local cmkId = subResources["cmk"].Id ]
                    [#local cmkResourceId = subResources["cmk"].ResourceId]
                    [#local cmkName = subResources["cmk"].Name ]
                    [#local cmkAliasId = subResources["cmkAlias"].Id]
                    [#local cmkAliasName = subResources["cmkAlias"].Name]


                    [#local _context =
                        {
                            "Links" : contextLinks,
                            "Policy" : []
                        }
                    ]
                    [#local _context = invokeExtensions( subOccurrence, _context )]

                    [#if ( deploymentSubsetRequired(BASELINE_COMPONENT_TYPE, true) && legacyCmk == false ) ||
                        ( deploymentSubsetRequired("cmk") && legacyCmk == true) ]

                        [#-- Set the root policy as the default policy --]
                        [#-- Extensions provide any additional policies --]
                        [@createCMK
                            id=cmkResourceId
                            description=cmkName
                            statements=
                                [
                                    getPolicyStatement(
                                        "kms:*",
                                        "*",
                                        {
                                            "AWS": formatAccountPrincipalArn()
                                        }
                                    )
                                ] + _context.Policy
                            outputId=cmkId
                        /]

                        [@createCMKAlias
                            id=cmkAliasId
                            name=cmkAliasName
                            cmkId=cmkResourceId
                        /]
                    [/#if]
                [#break]

                [#case "ssh" ]

                    [#local localKeyPairId = subResources["localKeyPair"].Id]
                    [#local localKeyPairPublicKey = subResources["localKeyPair"].PublicKey ]
                    [#local localKeyPairPrivateKey = subResources["localKeyPair"].PrivateKey ]

                    [#local ec2KeyPairId = subResources["ec2KeyPair"].Id ]
                    [#local ec2KeyPairName = subResources["ec2KeyPair"].Name ]
                    [#local legacyKey = subResources["ec2KeyPair"].LegacyKey ]

                    [#if deploymentSubsetRequired("epilogue", false)]
                        [#-- Make sure SSH credentials are in place --]
                        [@addToDefaultBashScriptOutput
                            content=
                            [
                                r'function manage_ssh_credentials() {',
                                r'  info "Checking SSH credentials ..."',
                                r'  # Create SSH credential for the segment',
                                r'  mkdir -p "${SEGMENT_OPERATIONS_DIR}"',
                                r'  create_pki_credentials "${SEGMENT_OPERATIONS_DIR}" ' +
                                        r'"' + getRegion() + r'" ' +
                                        r'"' + accountObject.Id + r'" ' +
                                        r'"' + localKeyPairPublicKey + r'" ' +
                                        r'"' + localKeyPairPrivateKey + r'" ' +
                                        r'"' + legacyKey?c + r'" || return $?',
                                r'  # Update the credential if required',
                                r'  if ! check_ssh_credentials "'+ getRegion() + r'" "${key_pair_name}"; then',
                                r'    update_ssh_credentials "' + getRegion() + r'" ' +
                                    r'"${key_pair_name}" ' +
                                    r'"${SEGMENT_OPERATIONS_DIR}/' + localKeyPairPrivateKey + r'.plaintext" || return $?',
                                r'    [[ -f "${SEGMENT_OPERATIONS_DIR}/' + localKeyPairPrivateKey + r'.plaintext" ]] && ',
                                r'      { encrypt_kms_file' + " " +
                                        r'"' + getRegion() + r'" ' +
                                        r'"${SEGMENT_OPERATIONS_DIR}/' + localKeyPairPrivateKey + r'.plaintext" ' +
                                        r'"${SEGMENT_OPERATIONS_DIR}/' + localKeyPairPrivateKey + r'" ' +
                                        r'"' + cmkAlias + r'" || return $?; }',
                                r'  fi'
                            ] +
                            pseudoStackOutputScript(
                                "SSH Key Pair",
                                {
                                    ec2KeyPairId : r'${key_pair_name}',
                                    formatId(ec2KeyPairId, "name") : r'${key_pair_name}',
                                    formatId(localKeyPairId, KEY_ATTRIBUTE_TYPE) : r'$( cat "${SEGMENT_OPERATIONS_DIR}/' + localKeyPairPrivateKey + r'" )'
                                },
                                ( legacyKey || subCore.SubComponent.RawId == "ssh")?then(
                                    "keypair",
                                    "keypair-${subCore.SubComponent.RawName}"
                                )
                            ) +
                            valueIfTrue(
                                [
                                    r'   info "Removing old ssh pseudo stack output ..."',
                                    r'   legacy_pseudo_stack_file="$(fileBase "${BASH_SOURCE}")"',
                                    r'   legacy_pseudo_stack_filepath="${CF_DIR/baseline/cmk}${legacy_pseudo_stack_file/-baseline-/-cmk-}-keypair-pseudo-stack.json"',
                                    r'   if [ -f "${legacy_pseudo_stack_filepath}" ]; then',
                                    r'       info "Deleting ${legacy_pseudo_stack_filepath} ..."',
                                    r'       rm -f "${legacy_pseudo_stack_filepath}"',
                                    r'   else',
                                    r'       warn "Unable to locate pseudo stack file ${legacy_pseudo_stack_filepath}"',
                                    r'   fi'
                                ],
                                legacyKey,
                                []
                            ) +
                            [
                                r'  show_ssh_credentials "' + getRegion() + r'" "${key_pair_name}"',
                                r'}',
                                r'# Determine the required key pair name',
                                r'key_pair_name="' + ec2KeyPairName + r'"',
                                r'case ${STACK_OPERATION} in',
                                r'  delete)',
                                r'    delete_ssh_credentials "'+ getRegion() + r'" ' +
                                        r'"${key_pair_name}" || return $?',
                                r'    delete_pki_credentials "${SEGMENT_OPERATIONS_DIR}" || return $?',
                                r'    rm -f "${CF_DIR}/$(fileBase "${BASH_SOURCE}")-keypair-pseudo-stack.json"',
                                r'    ;;',
                                r'  create|update)',
                                r'    manage_ssh_credentials || return $?',
                                r'    ;;',
                                r' esac'
                            ]
                        /]
                    [/#if]
                [#break]

                [#case "oai" ]

                    [#local OAIId = subResources["originAccessId"].Id ]
                    [#local OAIName = subResources["originAccessId"].Name ]
                    [#local legacyKey = false]

                    [#if subCore.SubComponent.Id == "oai" ]

                        [#-- legacy OAI lookup --]
                        [#local opsDataLink = {
                                    "Id" : "opsData",
                                    "Name" : "opsData",
                                    "Tier" : "mgmt",
                                    "Component" : "baseline",
                                    "Instance" : "",
                                    "Version" : "",
                                    "DataBucket" : "opsdata"
                            }]

                        [#local opsDataLinkTarget = getLinkTarget(occurrence, opsDataLink )]

                        [#if opsDataLinkTarget?has_content ]
                            [#local opsDataBucketId = opsDataLinkTarget.State.Resources["bucket"].Id ]
                            [#local legacyOAIId = formatDependentCFAccessId(opsDataBucketId)]
                            [#local legacyOAIName = formatSegmentFullName()]

                            [#if (getExistingReference(legacyOAIId, CANONICAL_ID_ATTRIBUTE_TYPE))?has_content ]
                                [#local legacyKey = true]
                            [/#if]
                        [/#if]
                    [/#if]

                    [#if deploymentSubsetRequired(BASELINE_COMPONENT_TYPE, true)]
                        [@createCFOriginAccessIdentity
                            id=OAIId
                            name=OAIName
                        /]
                    [/#if]

                    [#if legacyKey ]
                        [#if deploymentSubsetRequired("epilogue", false) ]
                            [@addToDefaultBashScriptOutput
                                content=
                                    [
                                        "case $\{STACK_OPERATION} in",
                                        "  delete)",
                                        "    delete_oai_credentials" + " " +
                                               "\"" + getRegion() + "\" " +
                                               "\"" + legacyOAIName + "\" || return $?",
                                        "    rm -f \"$\{CF_DIR}/$(fileBase \"$\{BASH_SOURCE}\")-pseudo-stack.json\"",
                                        "    ;;",
                                        "  create|update)",
                                        "    info \"Removing legacy oai credential ...\"",
                                        "    used=$(is_oai_credential_used" + " " +
                                               "\"" + getRegion() + "\" " +
                                               "\"" + legacyOAIName + "\" ) || return $?",
                                        "    if [[ \"$\{used}\" == \"true\" ]]; then",
                                        "      warn \"Legacy OAI in use - rerun the baseline unit to remove it once it is no longer in use ...\"",
                                        "    else",
                                        "      delete_oai_credentials" + " " +
                                                 "\"" + getRegion() + "\" " +
                                                 "\"" + legacyOAIName + "\" || return $?",
                                        "      info \"Removing legacy oai pseudo stack output\"",
                                        "      legacy_pseudo_stack_file=\"$(fileBase \"$\{BASH_SOURCE}\")\"",
                                        "      legacy_pseudo_stack_filepath=\"$\{CF_DIR/baseline/cmk}/$\{legacy_pseudo_stack_file/-baseline-/-cmk-}-pseudo-stack.json\"",
                                        "      if [ -f \"$\{legacy_pseudo_stack_filepath}\" ]; then",
                                        "         info \"Deleting $\{legacy_pseudo_stack_filepath} ...\"",
                                        "         rm -f \"$\{legacy_pseudo_stack_filepath}\"",
                                        "      else",
                                        "         warn \"Unable to locate pseudo stack file $\{legacy_pseudo_stack_filepath}\"",
                                        "      fi",
                                        "    fi",
                                        "    ;;",
                                        " esac"
                                    ]
                            /]
                        [/#if]
                    [/#if]
                [#break]
            [/#switch]
        [/#if]
    [/#list]
[/#macro]
