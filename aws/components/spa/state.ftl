[#ftl]

[#macro aws_spa_cf_state occurrence parent={} ]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local cfId  = formatComponentCFDistributionId(core.Tier, core.Component, occurrence)]

    [#-- Baseline component lookup --]
    [#-- Allow for possibility buckets haven't been created yet --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "OpsData" ], true, false )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]

    [#local operationsBucketId = baselineComponentIds["OpsData"]!"" ]
    [#local operationsBucket = getExistingReference(AWS_PROVIDER, operationsBucketId) ]

    [#local configFilePath = formatRelativePath(
                                getOccurrenceSettingValue(occurrence, "SETTINGS_PREFIX"),
                                "config" )]
    [#local configFileName = "config.json" ]

    [#assign componentState =
        {
            "Resources" : {
                "site" :{
                    "Id" : formatResourceId( SPA_COMPONENT_TYPE, core.Id ),
                    "Deployed" : true,
                    "Type" : SPA_COMPONENT_TYPE
                }
            } +
            getExistingReference(AWS_PROVIDER, cfId, "", "", getDeploymentUnit())?has_content?then(
                {
                    "legacyCF" : {
                        "Id" : cfId,
                        "Type" : AWS_CLOUDFRONT_DISTRIBUTION_RESOURCE_TYPE
                    }
                },
                {}
            ),
            "Attributes" : {
                "CONFIG_PATH_PATTERN" : solution.ConfigPathPattern,
                "CONFIG_BUCKET" : operationsBucket,
                "CONFIG_FILE" : formatRelativePath(
                                    configFilePath,
                                    configFileName
                                )
            },
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]
[/#macro]