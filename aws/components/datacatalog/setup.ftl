[#ftl]

[#macro aws_datacatalog_cf_deployment_generationcontract occurrence ]
    [@addDefaultGenerationContract subsets=["deploymentcontract", "template"] /]
[/#macro]

[#macro aws_datacatalog_cf_deployment_deploymentcontract occurrence ]
    [@addDefaultAWSDeploymentContract /]
[/#macro]

[#macro aws_datacatalog_cf_deployment occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]

    [#local database = resources["database"]]

    [#if deploymentSubsetRequired(DATACATALOG_COMPONENT_TYPE, true)]
        [@createAWSGlueDatabase
            id=database.Id
            name=database.Name
            description=(solution.Description)!""
        /]
    [/#if]

    [#list (occurrence.Occurrences![])?filter(
            x -> x.Configuration.Solution.Enabled
            && x.Core.Type == DATACATALOG_TABLE_COMPONENT_TYPE ) as subOccurrence]

        [#local core = subOccurrence.Core ]
        [#local solution = subOccurrence.Configuration.Solution ]
        [#local resources = subOccurrence.State.Resources ]

        [#local baselineLinks = getBaselineLinks(subOccurrence, [ "Encryption" ] )]
        [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]

        [#local table = resources["table"]]

        [#local locationPath = ""]
        [#local source = getLinkTarget(occurrence, solution.Source.Link )]

        [#if source?has_content ]
            [#switch source.Core.Type ]
                [#case S3_COMPONENT_TYPE ]
                [#case BASELINE_DATA_COMPONENT_TYPE ]
                    [#local locationPath = formatRelativePath(
                        "s3://${source.State.Attributes.NAME}",
                        solution.Source.Prefix
                    )]
                    [#break]

                [#default]
                    [@fatal
                        message="Unsupported source type"
                        context={
                            "Id" : subOccurrence.Core.Id,
                            "Name" : subOccurrence.Core.FullRawName,
                            "SourceType" : source.Core.Type,
                            "Source" : solution.Source.Link
                        }
                    /]
            [/#switch]
        [/#if]

        [#local partitionKeys = []]
        [#list solution.Layout.Partitioning as k,v ]
            [#if v.Enabled]
                [#local partitionKeys = combineEntities(
                    partitionKeys,
                    [
                        getAWSGlueTableColumn(
                            (v.Name)!k,
                            v.Type,
                            v.Description
                        )
                    ]
                )]
            [/#if]
        [/#list]

        [#local tableColumns = []]
        [#list solution.Layout.Columns as k,v ]
            [#if v.Enabled]
                [#local tableColumns = combineEntities(
                    tableColumns,
                    [
                        getAWSGlueTableColumn(
                            (v.Name)!k,
                            v.Type,
                            v.Description
                        )
                    ],
                    UNIQUE_COMBINE_BEHAVIOUR
                )]
            [/#if]
        [/#list]

        [#local tableParams = {}]
        [#list solution.Parameters as k,v]
            [#if v.Enabled ]
                [#local tableParams = mergeObjects(
                    tableParams,
                    {
                        (v.Key)!k: v.Value
                    }
                )]
            [/#if]
        [/#list]

        [#local serDeParams = {}]
        [#list solution.Format.Serialisation.Parameters as k,v ]
            [#if v.Enabled ]
                [#local serDeParams = mergeObjects(
                    serDeParams,
                    {
                        (v.Key)!k: v.Value
                    }
                )]
            [/#if]
        [/#list]

        [#local contextLinks = getLinkTargets(subOccurrence) ]
        [#local _context =
            {
                "DefaultEnvironment" : defaultEnvironment(subOccurrence, contextLinks, baselineLinks),
                "Environment" : {},
                "Links" : contextLinks,
                "BaselineLinks" : baselineLinks,
                "DefaultCoreVariables" : false,
                "DefaultEnvironmentVariables" : false,
                "DefaultLinkVariables" : false,
                "DefaultBaselineVariables" : false,
                "Policy" : [],
                "ManagedPolicy" : [],
                "SourceLink": source,
                "PartitionKeys": partitionKeys,
                "TableColumns" : tableColumns,
                "LocationPath" : locationPath
            }
        ]
        [#local _context = invokeExtensions(subOccurrence, _context )]

        [#local tableStorageDescriptor =
                getAWSGlueTableStorageDescriptor(
                    [],
                    _context.TableColumns,
                    solution.Source.DecompressData
                    solution.Format.Input,
                    _context.LocationPath,
                    0,
                    solution.Format.Output,
                    {},
                    {},
                    solution.Format.Serialisation.Library,
                    "",
                    serDeParams
                )]

        [#if deploymentSubsetRequired(DATACATALOG_COMPONENT_TYPE, true)]
            [@createAWSGlueTable
                id=table.Id
                name=table.Name
                databaseId=database.Id
                partitionKeys=_context.PartitionKeys
                storageDescriptor=tableStorageDescriptor
                parameters=tableParams
            /]
        [/#if]

        [#if solution.Crawler.Enabled ]
            [#local crawler = resources["crawler"]]
            [#local crawlerRole = resources["crawlerRole"]]
            [#local policySet = {} ]

            [#if deploymentSubsetRequired("iam", true) && isPartOfCurrentDeploymentUnit(roleId)]
                [#-- Gather the set of applicable policies --]
                [#-- Any permissions added via extensions --]
                [#local policySet =
                    addInlinePolicyToSet(
                        policySet,
                        formatDependentPolicyId(crawlerRole.Id),
                        _context.Name,
                        _context.Policy
                    )
                ]

                [#local policySet =
                    addInlinePolicyToSet(
                        policySet,
                        formatDependentPolicyId(crawlerRole.Id, "source"),
                        "source",
                        getLinkTargetsOutboundRoles(source)
                    )]

                [#-- Ensure we don't blow any limits as far as possible --]
                [#local policySet = adjustPolicySetForRole(policySet) ]

                [#-- Create any required managed policies --]
                [#-- They may result when policies are split to keep below AWS limits --]
                [@createCustomerManagedPoliciesFromSet policies=policySet /]

                [#-- Create a role under which the function will run and attach required policies --]
                [#-- The role is mandatory though there may be no policies attached to it --]
                [@createRole
                    id=crawlerRole.Id
                    trustedServices=[
                        "glue.amazonaws.com"
                    ]
                    managedArns=getManagedPoliciesFromSet(policySet)
                    tags=getOccurrenceTags(subOccurrence)
                /]

                [#-- Create any inline policies that attach to the role --]
                [@createInlinePoliciesFromSet policies=policySet roles=crawlerRole.Id /]
            [/#if]

            [#local targets = {
                "CatalogTargets" : [
                    getAWSGlueCrawlerTarget(
                        "catalog",
                        "",
                        database.Id,
                        [ table.Id ]
                    )
                ]
            }]

            [#if deploymentSubsetRequired(DATACATALOG_COMPONENT_TYPE, true)]
                [@createAWSGlueCrawler
                    id=cralwer.Id
                    name=crawler.Name
                    roleId=crawlerRole.Id
                    targets=targets
                    description=(solution.Description)!""
                    crawlerSecurityConfigurationId=""
                    glueDatabaseId=database.Id
                    recrawlBehaviour=solution.Crawler.RecrawlingPolicy
                    scheduleExpression=solution.Crawler.Schedule
                    schemaChangeDeleteBehaviour=solution.Crawler.SchemaChanges.Delete
                    schemaChangeUpdateBehaviour=solution.Crawler.SchemaChanges.Update
                    tags=getOccurrenceTags(subOccurrence)
                /]
            [/#if]
        [/#if]

    [/#list]
[/#macro]
