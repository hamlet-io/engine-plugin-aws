[#ftl]
[#macro aws_s3_cf_deployment_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract subsets=["deploymentcontract", "template"] /]
[/#macro]

[#macro aws_s3_cf_deployment_deploymentcontract occurrence ]
    [@addDefaultAWSDeploymentContract /]
[/#macro]

[#macro aws_s3_cf_deployment_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]
    [#local links = getLinkTargets(occurrence )]

    [#local s3Id = resources["bucket"].Id ]
    [#local s3Name = resources["bucket"].Name ]
    [#local s3Arn = formatGlobalArn("s3", s3Name, "")]

    [#local bucketPolicyId = resources["bucketpolicy"].Id ]

    [#local roleId = resources["role"].Id ]

    [#local versioningEnabled = solution.Versioning!solution.Lifecycle.Versioning ]

    [#-- TODO(mfl): remove once Lifecycle.Versioning atribute is removed --]
    [#if solution.Lifecycle.Versioning]
        [@warn
            message="Use of Lifecycle.Versioning have been deprecated"
            detail="Please use the top level Versioning attribute instead. NOTE: Default behaviour if enabling versioning under Lifecycle WILL lifecycle objects even if only Versioning is enabled."
        /]
    [/#if]

    [#local replicationEnabled = false]
    [#local replicationConfiguration = {} ]
    [#local replicationBucket = ""]
    [#local replicateEncryptedData = solution.Encryption.Enabled
                                        && solution.Encryption.EncryptionSource == "EncryptionService" ]
    [#local replicationCrossAccount = false ]
    [#local replicationDestinationAccountId = "" ]
    [#local replicationExternalPolicy = []]
    [#local replicationKMSKey = ""]

    [#local backupTags = {} ]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "CDNOriginKey", "Encryption" ])]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local cfAccessId  = getExistingReference(baselineComponentIds["CDNOriginKey"]!"", CANONICAL_ID_ATTRIBUTE_TYPE) ]

    [#local kmsKeyId = baselineComponentIds["Encryption"]]

    [#local dependencies = [] ]

    [#local notifications = []]

    [#list solution.Notifications?values?filter(x -> x?is_hash && x.Enabled) as notification ]
        [#list notification.Links?values as link]
            [#if link?is_hash]
                [#local linkTarget = getLinkTarget(occurrence, link, false) ]
                [@debug message="Link Target" context=linkTarget enabled=false /]
                [#if !linkTarget?has_content]
                    [#continue]
                [/#if]

                [#local linkTargetResources = linkTarget.State.Resources ]

                [#if isLinkTargetActive(linkTarget) ]

                    [#if ! getExistingReference(s3Id)?has_content ]
                        [@warn
                            message="Notification permissions required before enabling notifications"
                            detail="Update the notificaton destination and rerun this deployment"
                            context={
                                "S3_Bucket" : {
                                    "Id": occurrence.Core.RawId,
                                    "Tier": occurrence.Core.Tier.Id,
                                    "deployment:Unit": getOccurrenceDeploymentUnit(occurrence)
                                },
                                "Notification_Destination" : {
                                    "Id" : linkTarget.Core.RawId,
                                    "Tier" : linkTarget.Core.Tier.Id,
                                    "deployment:Unit" : getOccurrenceDeploymentUnit(linkTarget)
                                }
                            }
                        /]
                        [#continue]
                    [/#if]

                    [#local resourceId = "" ]
                    [#local resourceType = ""]

                    [#switch linkTarget.Core.Type]
                        [#case SQS_COMPONENT_TYPE ]
                            [#local resourceId = linkTargetResources["queue"].Id ]
                            [#local resourceType = linkTargetResources["queue"].Type ]
                            [#if ! (notification["aws:QueuePermissionMigration"]) ]
                                [#if deploymentSubsetRequired(S3_COMPONENT_TYPE, true)]
                                    [@fatal
                                        message="Queue Permissions update required"
                                        detail=[
                                            "SQS policies have been migrated to the queue component",
                                            "For each S3 bucket add an inbound-invoke link from the Queue to the bucket",
                                            "When this is completed update the configuration of this notification to aws:QueuePermissionMigration : true"
                                        ]
                                        context=notification
                                    /]
                                [/#if]
                            [/#if]
                            [#break]

                        [#case LAMBDA_FUNCTION_COMPONENT_TYPE ]
                            [#local resourceId = linkTargetResources["function"].Id ]
                            [#local resourceType = linkTargetResources["function"].Type ]

                            [#local policyId =
                                formatS3NotificationPolicyId(
                                    s3Id,
                                    resourceId) ]

                            [#local dependencies += [policyId] ]

                            [#if deploymentSubsetRequired("s3", true)]
                                [@createLambdaPermission
                                    id=policyId
                                    targetId=resourceId
                                    sourceId=formatGlobalArn("s3", s3Name, "")
                                    sourcePrincipal="s3.amazonaws.com"
                                /]
                            [/#if]

                            [#break]

                        [#case TOPIC_COMPONENT_TYPE]
                            [#local resourceId = linkTargetResources["topic"].Id ]
                            [#local resourceType = linkTargetResources["topic"].Type ]

                            [#if ! (notification["aws:TopicPermissionMigration"]) ]
                                [#if deploymentSubsetRequired(S3_COMPONENT_TYPE, true)]
                                    [@fatal
                                        message="Topic Permissions update required"
                                        detail=[
                                            "SNS policies have been migrated to the topic component",
                                            "For each S3 bucket add an inbound-invoke link from the Topic to the bucket",
                                            "When this is completed update the configuration of this notification to aws:TopicPermissionMigration : true"
                                        ]
                                        context=occurrence.Core.RawId
                                    /]
                                [/#if]
                            [/#if]
                    [/#switch]

                    [#list notification.Events as event ]
                        [#local notifications +=
                                getS3Notification(resourceId, resourceType, event, notification.Prefix, notification.Suffix) ]
                    [/#list]
                [/#if]
            [/#if]
        [/#list]
    [/#list]

    [#local policyStatements = [] ]

    [#if solution.Encryption.Transit.Enabled ]
        [#local policyStatements += [
            getPolicyStatement(
                [
                    "s3:*"
                ],
                [
                    getArn(s3Id),
                    {
                        "Fn::Join": [
                            "/",
                            [
                                getArn(s3Id),
                                "*"
                            ]
                        ]
                    }
                ],
                "*",
                {
                    "Bool": {
                        "aws:SecureTransport": "false"
                    }
                },
                false
            )
        ]]
    [/#if]

    [#local publicPolicyRequired = false]
    [#list solution.PublicAccess?values?filter(x -> x.Enabled ) as publicAccessConfiguration]
        [#local publicPolicyRequired = true ]
        [#list publicAccessConfiguration.Paths as publicPrefix]
            [#local publicIPWhiteList =
                getIPCondition(getGroupCIDRs(publicAccessConfiguration.IPAddressGroups, true)) ]

            [#switch publicAccessConfiguration.Permissions ]
                [#case "ro" ]
                    [#local policyStatements += s3ReadPermission(
                                                    s3Name,
                                                    publicPrefix,
                                                    "*",
                                                    "*",
                                                    publicIPWhiteList)]
                    [#break]
                [#case "wo" ]
                    [#local policyStatements += s3WritePermission(
                                                    s3Name,
                                                    publicPrefix,
                                                    "*",
                                                    "*",
                                                    publicIPWhiteList)]
                    [#break]
                [#case "rw" ]
                    [#local policyStatements += s3AllPermission(
                                                    s3Name,
                                                    publicPrefix,
                                                    "*",
                                                    "*",
                                                    publicIPWhiteList)]
                    [#break]
            [/#switch]
        [/#list]
    [/#list]

    [#list solution.Links?values as link]
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
            [#local linkTargetRoles = linkTarget.State.Roles ]
            [#local linkDirection = linkTarget.Direction ]
            [#local linkRole = linkTarget.Role]

            [#switch linkTargetCore.Type]
                [#case MTA_RULE_COMPONENT_TYPE ]
                    [#if (linkDirection == "inbound") && (linkRole == "save") ]
                        [#local policyStatements +=
                            s3WritePermission(
                                s3Name,
                                linkTargetRoles.Inbound[linkRole].Prefix!"",
                                "*",
                                {"Service" : linkTargetRoles.Inbound[linkRole].Principal!""},
                                {
                                    "StringEquals" : {
                                        "aws:Referer" : linkTargetRoles.Inbound[linkRole].Referer!""
                                    }
                                }
                            )
                        ]
                    [/#if]
                    [#break]

                [#case CDN_COMPONENT_TYPE]
                [#case CDN_ROUTE_COMPONENT_TYPE ]

                    [#local cdnBaselineLinks = getBaselineLinks(linkTarget, [ "CDNOriginKey" ])]
                    [#local cdnBaselineComponentIds = getBaselineComponentIds(cdnBaselineLinks)]
                    [#local cdnCFAccessId  = getExistingReference(cdnBaselineComponentIds["CDNOriginKey"]!"", CANONICAL_ID_ATTRIBUTE_TYPE) ]

                    [#if linkDirection == "inbound" ]
                        [#local policyStatements +=
                            s3ReadPermission(
                                s3Name,
                                "",
                                "*",
                                {
                                    "CanonicalUser": cfAccessId
                                }
                            ) +
                            s3ListPermission(
                                s3Name,
                                "",
                                "*",
                                {
                                    "CanonicalUser": cfAccessId
                                }
                            )
                        ]
                    [/#if]
                    [#break]


                [#case EXTERNALSERVICE_COMPONENT_TYPE ]
                    [#switch linkRole ]
                        [#case "replicadestination" ]
                            [#local replicationEnabled = true]
                            [#local versioningEnabled = true]

                            [#local replicationDestinationAccountId = (linkTargetAttributes["ACCOUNT_ID"])!"" ]
                            [#local replicationExternalPolicy +=   s3ReplicaDestinationPermission( linkTargetAttributes["ARN"] ) ]
                            [#local replicationBucket = linkTargetAttributes["ARN"]]
                            [#local replicationKMSKey = (linkTargetAttributes["KMS_KEY_ARN"])!""]
                            [#local replicationKMSKeyRegion = (linkTargetAttributes["KMS_KEY_REGION"])!""]

                            [#if replicationKMSKey?has_content ]
                                [#local replicationExternalPolicy += s3EncryptionAllPermission(replicationKMSKey, replicationBucket, "*", replicationKMSKeyRegion)]
                            [/#if]

                            [#break]

                        [#case "save" ]
                            [#if linkDirection == "inbound" ]
                                [#local policyStatements +=
                                    s3WritePermission(
                                        s3Name,
                                        linkTargetAttributes["PREFIX"]!"",
                                        "*",
                                        {"Service" : linkTargetAttributes["SERVICE"]!""},
                                        {
                                            "StringEquals" : {
                                                "aws:Referer" : linkTargetAttributes["REFERER"]!""
                                            }
                                        }
                                    )
                                ]
                            [/#if]
                            [#break]
                    [/#switch]
                    [#break]


                [#case S3_COMPONENT_TYPE ]
                    [#if (linkDirection == "inbound") && (linkRole == "inventorysrc") ]
                        [#local policyStatements +=
                            s3InventorySerivcePermssion(s3Name,  linkTargetRoles.Inbound[linkRole].SourceArn)
                        ]
                    [/#if]

                    [#switch linkRole ]
                        [#case "replicadestination" ]
                            [#local replicationEnabled = true]
                            [#local versioningEnabled = true]

                            [#if deploymentSubsetRequired(S3_COMPONENT_TYPE, true) ]
                                [#if !replicationBucket?has_content ]
                                    [#if !linkTargetAttributes["ARN"]?has_content ]
                                        [#-- do not validate replica sequence on delete --]
                                        [#local deploymentMode = getDeploymentMode()]
                                        [#local deploymentModeDetails = getDeploymentModeDetails(deploymentMode)]
                                        [#local deploymentModeOperations = deploymentModeDetails.Operations]

                                        [#if !(deploymentModeOperations?seq_contains("delete") ) ]
                                            [@fatal
                                                message="Replication destination must be deployed before source"
                                                context=
                                                    linkTarget
                                            /]
                                        [/#if]
                                    [/#if]
                                    [#local replicationBucket = linkTargetAttributes["ARN"]]
                                [#else]
                                    [@fatal
                                        message="Only one replication destination is supported"
                                        context=links
                                    /]
                                [/#if]
                            [/#if]
                            [#break]

                        [#case "replicasource" ]
                            [#local versioningEnabled = true]
                            [#break]
                    [/#switch]
                    [#break]

                [#case BACKUPSTORE_REGIME_COMPONENT_TYPE]
                    [#if linkTargetAttributes["TAG_NAME"]?has_content]
                        [#local backupTags = mergeObjects(
                                backupTags,
                                {linkTargetAttributes["TAG_NAME"], linkTargetAttributes["TAG_VALUE"]}
                            )]
                    [#else]
                        [@warn
                            message="Ignoring linked backup regime \"${linkTargetCore.SubComponent.Name}\" that does not support tag based inclusion"
                            context=linkTargetCore
                        /]
                    [/#if]
                    [#break]

            [/#switch]
        [/#if]
    [/#list]

    [#-- Add Replication Rules --]
    [#if replicationEnabled ]
        [#local replicationRules = [] ]
        [#list solution.Replication.Prefixes as prefix ]
            [#local replicationRules +=
                [ getS3ReplicationRule(
                    replicationBucket,
                    solution.Replication.Enabled,
                    prefix,
                    replicateEncryptedData,
                    replicationKMSKey?has_content?then(
                        replicationKMSKey,
                        kmsKeyId
                    ),
                    replicationDestinationAccountId
                )]]
        [/#list]

        [#local replicationConfiguration = getS3ReplicationConfiguration(
                                                roleId,
                                                replicationRules
                                            )]
    [/#if]

    [#local contextLinks = getLinkTargets(occurrence) ]
    [#local _context =
        {
            "Links" : contextLinks,
            "Policy" : []
        }
    ]
    [#local _context = invokeExtensions( occurrence, _context )]


    [#if deploymentSubsetRequired("iam", true) &&
            isPartOfCurrentDeploymentUnit(roleId)]
        [#local linkPolicies =
            getLinkTargetsOutboundRoles(links) +
            (replicationEnabled && replicateEncryptedData)?then(
                s3EncryptionReadPermission(
                    kmsKeyId,
                    s3Name,
                    "*",
                    getExistingReference(s3Id, REGION_ATTRIBUTE_TYPE)
                ),
                []
            )]

        [#local rolePolicies =
                arrayIfContent(
                    [getPolicyDocument(linkPolicies, "links")],
                    linkPolicies) +
                arrayIfContent(
                    getPolicyDocument(
                        s3ReplicaSourceBatchPermission(s3Id) +
                        s3ReplicaSourcePermission(s3Id) +
                        s3ReplicationConfigurationPermission(s3Id),
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

        [#if rolePolicies?has_content ]
            [@createRole
                id=roleId
                trustedServices=[
                    "s3.amazonaws.com"
                    [#-- Included here so that the same IAM Role can be used for batch replication --]
                    "batchoperations.s3.amazonaws.com"
                ]
                policies=rolePolicies
                tags=getOccurrenceTags(occurrence)
            /]
        [/#if]
    [/#if]


    [#local inventoryReports = []]
    [#list solution.InventoryReports as reportId,inventoryReport ]
        [#switch inventoryReport.Destination.Type ]
            [#case "self"]
                [#local inventoryId = reportId]
                    [#local inventoryReports += [
                        getS3InventoryReportConfiguration(
                            inventoryId,
                            inventoryReport.InventoryFormat,
                            s3Arn,
                            inventoryReport.Schedule
                            inventoryReport.InventoryPrefix,
                            inventoryReport.DestinationPrefix,
                            inventoryReport.IncludeVersions
                        )]]
                    [#local policyStatements += s3InventorySerivcePermssion(s3Name, s3Arn)]
                [#break]

            [#case "link"]

                [#list inventoryReport.Destination.Links as linkId,link]

                    [#local inventoryId = formatName(reportId, linkId)]

                    [#if link?is_hash]

                        [#local linkTarget = getLinkTarget(occurrence, link, false) ]
                        [@debug message="Link Target" context=linkTarget enabled=false /]

                        [#if !linkTarget?has_content]
                            [#continue]
                        [/#if]

                        [#local linkTargetCore = linkTarget.Core ]
                        [#local linkTargetAttributes = linkTarget.State.Attributes ]

                        [#switch linkTargetCore.Type ]
                            [#case S3_COMPONENT_TYPE ]
                            [#case BASELINE_DATA_COMPONENT_TYPE ]
                                [#local inventoryReports += [
                                        getS3InventoryReportConfiguration(
                                            inventoryId,
                                            inventoryReport.InventoryFormat,
                                            linkTargetAttributes["ARN"],
                                            inventoryReport.Schedule
                                            inventoryReport.InventoryPrefix,
                                            inventoryReport.DestinationPrefix,
                                            inventoryReport.IncludeVersions
                                        )]]
                                [#break]

                            [#default]
                                [@fatal
                                    message="Unsupported inventory report destination"
                                    detail="Supported types ${S3_COMPONENT_TYPE}, ${BASELINE_DATA_COMPONENT_TYPE}"
                                    context={ "Id" : occurrence.Core.Id, "InventoryReport" : inventoryReport }
                                /]
                        [/#switch]
                    [/#if]
                [/#list]
                [#break]
        [/#switch]
    [/#list]

    [#local objectOwnership = solution.ObjectOwnership!""]


    [#if deploymentSubsetRequired("s3", true)]

        [#if _context.Policy?has_content ]
            [#local policyStatements += _context.Policy /]
        [/#if]
        [#if policyStatements?has_content ]
            [@createBucketPolicy
                id=bucketPolicyId
                bucketId=s3Id
                statements=policyStatements
            /]
        [/#if]

        [@createS3Bucket
            id=s3Id
            name=s3Name
            lifecycleRules=
                (isPresent(solution.Lifecycle) && ((solution.Lifecycle.Expiration!operationsExpiration)?has_content || (solution.Lifecycle.Offline!operationsOffline)?has_content))?then(
                        getS3LifecycleRule(solution.Lifecycle.Expiration!operationsExpiration, solution.Lifecycle.Offline!operationsOffline),
                        []
                )
            notifications=notifications
            websiteConfiguration=
                (isPresent(solution.Website))?then(
                    getS3WebsiteConfiguration(solution.Website.Index, solution.Website.Error),
                    {})
            versioning=versioningEnabled
            CORSBehaviours=solution.CORSBehaviours
            replicationConfiguration=replicationConfiguration
            encrypted=solution.Encryption.Enabled
            encryptionSource=solution.Encryption.EncryptionSource
            kmsKeyId=kmsKeyId
            inventoryReports=inventoryReports
            dependencies=dependencies
            tags=mergeObjects(getOccurrenceTags(occurrence), backupTags)
            publicAccessBlockConfiguration=(
                getPublicAccessBlockConfiguration( !publicPolicyRequired, true, true, !publicPolicyRequired)
            )
            objectOwnershipConfiguration=(
                getS3ObjectOwnershipConfiguration(objectOwnership)
            )
        /]
    [/#if]
[/#macro]
