[#ftl]

[#-- Resources --]
[#assign DATASET_S3_SNAPSHOT_RESOURCE_TYPE = "s3Snapshot" ]

[#macro aws_dataset_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution ]

    [#local dataSetDeploymentUnit = getOccurrenceDeploymentUnit(occurrence)!"" ]

    [#local attributes = {
            "DATASET_ENGINE" : solution.Engine
    }]
    [#local resources = {}]
    [#local image = {}]

    [#local producePolicy = []]
    [#local consumePolicy = []]

    [#local codeBuildEnv = productObject.Builds.Data.Environment ]

    [#switch solution.Engine ]
        [#case "s3" ]
            [#local image = constructAWSImageResource(occurrence, "dataset", {}, "default")]
            [#local datasetPrefix = formatRelativePath(solution.Prefix)]

            [#local attributes += {
                "DATASET_PREFIX" : datasetPrefix,
                "DATASET_REGISTRY" : image.default.RegistryPath,
                "DATASET_LOCATION" : image.default.ImageLocation
            }]

            [#local consumePolicy +=
                    s3ConsumePermission(
                        (image.default.RegistryPath)?keep_after("s3://")?keep_before("/"),
                        (image.default.RegistryPath)?keep_after("s3://")?keep_after("/")
                    )
                ]

            [#local resources += {
                "datasetS3" : {
                    "Id" : formatId(DATASET_S3_SNAPSHOT_RESOURCE_TYPE, core.Id),
                    "Type" : DATASET_S3_SNAPSHOT_RESOURCE_TYPE,
                    "Deployed" : true
                }
            }]

            [#break]

        [#case "rds" ]
            [#local image = constructAWSImageResource(occurrence, "rdssnapshot")]
            [#local attributes += {
                "SNAPSHOT_NAME" : image.default.ImageLocation,
                "DATASET_LOCATION" : image.default.ImageLocation
            }]

            [#local resources += {
                "datasetRDS" : {
                    "Id" : formatId(AWS_RDS_SNAPSHOT_RESOURCE_TYPE, core.Id),
                    "Type" : AWS_RDS_SNAPSHOT_RESOURCE_TYPE,
                    "Deployed" : true
                }
            }]

            [#break]
    [/#switch]

    [#if codeBuildEnv == environmentObject.Id ]
        [#local linkCount = 0 ]
        [#list solution.Links?values as link]
            [#if link?is_hash]
                [#local linkCount += 1 ]
                [#if linkCount > 1 ]
                    [@fatal
                        message="A data set can only have one data source"
                        context=subOccurrence
                    /]
                    [#continue]
                [/#if]

                [#local linkTarget = getLinkTarget(occurrence, link) ]

                [@debug message="Link Target" context=linkTarget enabled=false /]

                [#if !linkTarget?has_content]
                    [#continue]
                [/#if]

                [#local linkTargetCore = linkTarget.Core ]
                [#local linkTargetConfiguration = linkTarget.Configuration ]
                [#local linkTargetResources = linkTarget.State.Resources ]
                [#local linkTargetAttributes = linkTarget.State.Attributes ]

                [#local attributes += linkTargetAttributes]

                [#switch linkTargetCore.Type]
                    [#case S3_COMPONENT_TYPE ]
                        [#local attributes += {
                            "DATASET_MASTER_LOCATION" :  "s3://" + linkTargetAttributes.NAME + formatAbsolutePath(datasetPrefix )
                        }]
                        [#local producePolicy += s3ProducePermission(
                                                    linkTargetAttributes.NAME,
                                                    datasetPrefix
                            )]
                        [#break]

                    [#case ES_COMPONENT_TYPE]
                        [#local attributes += {
                            "DATASET_MASTER_LOCATION" : "s3://" + linkTargetAttributes["SNAPSHOT_BUCKET"] + formatAbsolutePath(linkTargetAttributes["SNAPSHOT_PATH"]),
                            "DATASET_PREFIX" : linkTargetAttributes["SNAPSHOT_PATH"],
                            "NAME" : linkTargetAttributes["SNAPSHOT_BUCKET"]
                        }]
                        [#local producePolicy += s3ProducePermission(
                                                    linkTargetAttributes["SNAPSHOT_BUCKET"],
                                                    linkTargetAttributes["SNAPSHOT_PATH"]
                        )]
                        [#break]

                    [#case DB_COMPONENT_TYPE ]
                        [#break]

                    [#default]
                        [#local attributes += {
                            "DATASET_ENGINE" : "HamletFatal: DataSet Support not available for " + linkTargetCore.Type
                        }]
                [/#switch]
            [/#if]
        [/#list]
    [/#if]

    [#assign componentState =
        {
            "Resources" : resources,
            "Attributes" : attributes,
            "Images": image,
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {
                    "default" : "consume",
                    "produce" : producePolicy,
                    "consume" : consumePolicy
                }
            }
        }
    ]
[/#macro]
