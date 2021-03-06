[#ftl]
[#macro aws_datafeed_cf_deployment_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract subsets="template" /]
[/#macro]

[#macro aws_datafeed_cf_deployment_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]
    [#local resources = occurrence.State.Resources]

    [#local streamId = resources["stream"].Id ]
    [#local streamName = resources["stream"].Name ]

    [#local streamRoleId = resources["role"].Id ]
    [#local streamRolePolicyId = formatDependentPolicyId(streamRoleId, "local")]

    [#local streamLgId = (resources["lg"].Id)!"" ]
    [#local streamLgName = (resources["lg"].Name)!"" ]
    [#local streamLgStreamId = (resources["streamlgstream"].Id)!""]
    [#local streamLgStreamName = (resources["streamlgstream"].Name)!""]
    [#local streamLgBackupId = (resources["backuplgstream"].Id)!""]
    [#local streamLgBackupName = (resources["backuplgstream"].Name)!""]

    [#local logging = solution.Logging ]
    [#local encrypted = solution.Encrypted]

    [#local streamProcessors = []]

    [#local loggingProfile = getLoggingProfile(occurrence)]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "AppData", "Encryption"] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local cmkKeyId            = baselineComponentIds["Encryption"]]

    [#local dataBucketId        = baselineComponentIds["AppData"]]
    [#local dataBucket          = getExistingReference(dataBucketId) ]
    [#local dataBucketPrefix    = getAppDataFilePrefix(occurrence) ]

    [#local dataBucketLink = baselineLinks["AppData"]]

    [#local backUpEncrypt = dataBucketLink.Configuration.Solution.Encryption.Enabled &&
                dataBucketLink.Configuration.Solution.Encryption.EncryptionSource == "EncryptionService" ]

    [#local backUpBaselineLinks = getBaselineLinks( dataBucketLink, ["Encryption"]) ]
    [#local backUpCmkKeyId = getBaselineComponentIds(backUpBaselineLinks)["Encryption"]]


    [#if solution.LogWatchers?has_content ]
        [#local streamSubscriptionRoleId = resources["subscriptionRole"].Id!"" ]
        [#local streamSubscriptionPolicyId = formatDependentPolicyId(streamSubscriptionRoleId, "local")]
    [/#if]

    [#if logging ]

        [@setupLogGroup
            occurrence=occurrence
            logGroupId=streamLgId
            logGroupName=streamLgName
            loggingProfile=loggingProfile
        /]

        [#if deploymentSubsetRequired("lg", true) && isPartOfCurrentDeploymentUnit(streamLgId) ]
            [@createLogStream
                id=streamLgStreamId
                name=streamLgStreamName
                logGroup=streamLgName
                dependencies=streamLgId
            /]

            [@createLogStream
                id=streamLgBackupId
                name=streamLgBackupName
                logGroup=streamLgName
                dependencies=streamLgId
            /]

        [/#if]
    [/#if]

    [#list solution.LogWatchers as logWatcherName,logwatcher ]

        [#local logSubscriptionRoleRequired = true ]

        [#list logwatcher.Links as logWatcherLinkName,logWatcherLink ]
            [#local logWatcherLinkTarget = getLinkTarget(occurrence, logWatcherLink) ]

            [#if !logWatcherLinkTarget?has_content]
                [#continue]
            [/#if]

            [#local roleSource = logWatcherLinkTarget.State.Roles.Inbound["logwatch"]]

            [#list asArray(roleSource.LogGroupIds) as logGroupId ]

                [#local logGroupArn = getExistingReference(logGroupId, ARN_ATTRIBUTE_TYPE)]

                [#if logGroupArn?has_content ]

                    [#if deploymentSubsetRequired(DATAFEED_COMPONENT_TYPE, true)]
                        [@createLogSubscription
                            id=formatDependentLogSubscriptionId(streamId, logWatcherLink.Id, logGroupId?index)
                            logGroupName=getExistingReference(logGroupId)
                            logFilterId=logwatcher.LogFilter
                            destination=streamId
                            role=streamSubscriptionRoleId
                            dependencies=streamId
                        /]
                    [/#if]
                [/#if]
            [/#list]
        [/#list]
    [/#list]

    [#local links = getLinkTargets(occurrence) ]
    [#local linkPolicies = []]

    [#list links as linkId,linkTarget]

        [#local linkTargetCore = linkTarget.Core ]
        [#local linkTargetConfiguration = linkTarget.Configuration ]
        [#local linkTargetResources = linkTarget.State.Resources ]
        [#local linkTargetAttributes = linkTarget.State.Attributes ]

        [#switch linkTargetCore.Type]
            [#case LAMBDA_FUNCTION_COMPONENT_TYPE]

                [#local linkPolicies += lambdaKinesisPermission( linkTargetAttributes["ARN"])]

                [#local streamProcessors +=
                        [ getFirehoseStreamLambdaProcessor(
                            linkTargetAttributes["ARN"],
                            streamRoleId,
                            solution.Buffering.Interval,
                            solution.Buffering.Size
                        )]]
                [#break]

            [#default]
                [#local linkPolicies += getLinkTargetsOutboundRoles( { linkId, linkTarget} ) ]
        [/#switch]
    [/#list]

    [#local destinationLink = getLinkTarget(
                                    occurrence,
                                    solution.Destination.Link +
                                    {
                                        "Role" : "datafeed"
                                    }
                                )]

    [#if destinationLink?has_content ]
        [#local linkPolicies += getLinkTargetsOutboundRoles( { "destination", destinationLink} ) ]
    [/#if]

    [#if deploymentSubsetRequired("iam", true)]

        [#if isPartOfCurrentDeploymentUnit(streamRoleId)]

            [@createRole
                id=streamRoleId
                trustedServices=[ "firehose.amazonaws.com" ]
                policies=
                    [
                        getPolicyDocument(
                            encrypted?then(
                                s3EncryptionKinesisPermission(
                                        cmkKeyId,
                                        dataBucket,
                                        dataBucketPrefix,
                                        regionId
                                ),
                                []
                            ) +
                            logging?then(
                                cwLogsProducePermission(streamLgName),
                                []
                            ) +
                            s3AllPermission(dataBucket, dataBucketPrefix),
                            "base"
                        )
                    ] +
                    arrayIfContent(
                        [getPolicyDocument(linkPolicies, "links")],
                        linkPolicies)
            /]
        [/#if]

        [#if solution.LogWatchers?has_content &&
                isPartOfCurrentDeploymentUnit(streamSubscriptionRoleId)]

            [@createRole
                id=streamSubscriptionRoleId
                trustedServices=[ formatDomainName("logs", regionId, "amazonaws.com") ]
            /]
        [/#if]
    [/#if]

    [#if deploymentSubsetRequired(DATAFEED_COMPONENT_TYPE, true)]

        [#local streamDependencies = []]

        [#if !streamProcessors?has_content && solution.LogWatchers?has_content ]
            [@fatal
                message="Lambda stream processor required for CloudwatchLogs"
                detail="Add the lambda as a link to this feed"
                context=occurrence
            /]
        [/#if]

        [#if solution.LogWatchers?has_content ]
            [@createPolicy
                id=streamSubscriptionPolicyId
                name="local"
                statements=
                            (solution.LogWatchers?has_content)?then(
                                firehoseStreamCloudwatchPermission(streamId)  +
                                    iamPassRolePermission(
                                        getReference(streamSubscriptionRoleId, ARN_ATTRIBUTE_TYPE)
                                ),
                                []
                            )
                roles=streamSubscriptionRoleId
            /]
        [/#if]

        [#local streamLoggingConfiguration = getFirehoseStreamLoggingConfiguration(
                                                logging
                                                streamLgName
                                                streamLgStreamName )]

        [#local streamBackupLoggingConfiguration = getFirehoseStreamLoggingConfiguration(
                                                logging,
                                                streamLgName,
                                                streamLgBackupName )]

        [#local streamS3BackupDestination = getFirehoseStreamBackupS3Destination(
                                                dataBucketId,
                                                dataBucketPrefix,
                                                solution.Buffering.Interval,
                                                solution.Buffering.Size,
                                                streamRoleId,
                                                backUpEncrypt,
                                                backUpCmkKeyId,
                                                streamBackupLoggingConfiguration )]

        [#local includeOrder = solution.Bucket.Include.Order ]
        [#switch (destinationLink.Core.Type)!"notfound" ]
            [#case BASELINE_DATA_COMPONENT_TYPE]
                [#if !(includeOrder?seq_contains("ComponentPath")) || !(solution.Bucket.Include.ComponentPath) ]
                    [@fatal
                        message="datafeed destination for baseline data must include ComponentPath in prefix"
                        context={
                            "Id": core.Id,
                            "Destination" : solution.Destination.Link,
                            "Bucket.Include" : solution.Bucket.Include
                        }
                    /]
                [/#if]

                [#-- continue to s3 case --]
            [#case S3_COMPONENT_TYPE ]

                [#-- Establish bucket prefixes --]
                [#local prefixIncludes = [ ] ]
                [#list includeOrder as includePrefix ]
                    [#if includePrefix == "AccountId" && solution.Bucket.Include.AccountId ]
                        [#local prefixIncludes += [ { "Ref" : "AWS::AccountId" } ]]
                    [/#if]
                    [#if includePrefix == "ComponentPath" && solution.Bucket.Include.ComponentPath ]
                        [#local prefixIncludes += [ occurrence.Core.FullRelativePath?ensure_ends_with("/") ]]
                    [/#if]
                [/#list]

                [#local streamS3DestinationPrefix = {
                    "Fn::Join" : [
                        "/",
                        [  (solution.Bucket.Prefix)?remove_ending("/") ] +
                        prefixIncludes
                    ]
                }]

                [#local streamS3DestinationErrorPrefix = {
                    "Fn::Join" : [
                        "/",
                        [ (solution.Bucket.ErrorPrefix)?remove_ending("/") ] +
                        prefixIncludes
                    ]
                }]

                [#local s3Encrypt = destinationLink.Configuration.Solution.Encryption.Enabled &&
                                        destinationLink.Configuration.Solution.Encryption.EncryptionSource == "EncryptionService" ]

                [#local s3BaselineLinks = getBaselineLinks(destinationLink, [ "Encryption"] )]
                [#local s3BaselineComponentIds = getBaselineComponentIds(s3BaselineLinks)]

                [#local s3Id = destinationLink.State.Resources["bucket"].Id ]
                [#local streamS3Destination = getFirehoseStreamS3Destination(
                                                s3Id,
                                                streamS3DestinationPrefix,
                                                streamS3DestinationErrorPrefix,
                                                solution.Buffering.Interval,
                                                solution.Buffering.Size,
                                                streamRoleId,
                                                s3Encrypt,
                                                s3BaselineComponentIds["Encryption"],
                                                streamLoggingConfiguration,
                                                solution.Backup.Enabled,
                                                streamS3BackupDestination,
                                                streamProcessors
                )]

                [@createFirehoseStream
                    id=streamId
                    name=streamName
                    destination=streamS3Destination
                    dependencies=streamDependencies
                /]
                [#break]

            [#case ES_COMPONENT_TYPE ]

                [#local esId = destinationLink.State.Resources["es"].Id ]
                [#local streamESDestination = getFirehoseStreamESDestination(
                                                solution.Buffering.Interval,
                                                solution.Buffering.Size,
                                                esId,
                                                streamRoleId,
                                                solution.ElasticSearch.IndexPrefix,
                                                solution.ElasticSearch.IndexRotation,
                                                solution.ElasticSearch.DocumentType,
                                                solution.Backup.FailureDuration,
                                                solution.Backup.Policy,
                                                streamS3BackupDestination,
                                                streamLoggingConfiguration,
                                                streamProcessors)]

                [@createFirehoseStream
                    id=streamId
                    name=streamName
                    destination=streamESDestination
                    dependencies=streamDependencies
                /]
                [#break]

            [#default]
                [@fatal
                    message="Invalid stream destination or destination not found"
                    detail="Supported Destinations - ES"
                    context=occurrence
                /]
        [/#switch]
    [/#if]
[/#macro]
