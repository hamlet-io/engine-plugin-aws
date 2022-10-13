[#ftl]

[#-- Resources --]
[#assign HAMLET_MOBILEAPP_RESOURCE_TYPE = "mobileapp"]

[#macro aws_mobileapp_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local id = formatResourceId(HAMLET_MOBILEAPP_RESOURCE_TYPE, core.Id)]

    [#local otaBucket = ""]
    [#local otaPrefix = core.RelativePath ]
    [#local otaURL = ""]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "OpsData" ], true, false )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]

    [#local operationsBucket = getExistingReference(baselineComponentIds["OpsData"]!"") ]

    [#local configFilePath = formatRelativePath(
                                getOccurrenceSettingValue(occurrence, "SETTINGS_PREFIX"),
                                "config" )]
    [#local configFileName = "config.json" ]

    [#list solution.Links as id,link]
        [#if link?is_hash]
            [#local linkTarget = getLinkTarget(occurrence, link) ]

            [@debug message="Link Target" context=linkTarget enabled=false /]

            [#if !linkTarget?has_content]
                [#continue]
            [/#if]
            [#local linkTargetCore = linkTarget.Core ]
            [#local linkTargetAttributes = linkTarget.State.Attributes ]

            [#if ! linkTarget.Configuration.Solution.Enabled ]
                [#continue]
            [/#if]

            [#switch linkTargetCore.Type]
                [#case S3_COMPONENT_TYPE ]
                    [#if id?lower_case?starts_with("ota") ]
                        [#local otaBucket = linkTargetAttributes["NAME"]]
                        [#local otaS3URL = formatRelativePath("https://", linkTargetAttributes["INTERNAL_FQDN"], otaPrefix )]
                    [/#if]
                    [#break]
                [#case CDN_ROUTE_COMPONENT_TYPE ]
                    [#if id?lower_case?starts_with("ota")]
                        [#local otaCDNURL = formatRelativePath(linkTargetAttributes["URL"], otaPrefix )]
                    [/#if]
                    [#break]
            [/#switch]
        [/#if]
    [/#list]

    [#-- CDN OTA endpoint is preferred to an S3 OTA Endpoint --]
    [#if (otaCDNURL!"")?has_content ]
        [#local otaURL = otaCDNURL ]
    [#else]
        [#if (otaS3URL!"")?has_content ]
            [#local otaURL = otaS3URL ]
        [/#if]
    [/#if]

    [#assign componentState =
        {
            "Images": constructAWSImageResource(occurrence, "scripts"),
            "Resources" : {
                "mobileapp" : {
                    "Id" : id,
                    "Type" : HAMLET_MOBILEAPP_RESOURCE_TYPE,
                    "ConfigFilePath" : configFilePath,
                    "ConfigFileName" : configFileName,
                    "Deployed" : true
                }
            },
            "Attributes" : {
                "OTA_ARTEFACT_BUCKET" : otaBucket,
                "OTA_ARTEFACT_PREFIX" : otaPrefix,
                "OTA_ARTEFACT_URL" : otaURL,
                "CONFIG_BUCKET" : operationsBucket,
                "CONFIG_FILE" : formatRelativePath(
                                    configFilePath,
                                    configFileName
                                )
            }
        }
    ]
[/#macro]
