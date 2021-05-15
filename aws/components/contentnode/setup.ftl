[#ftl]
[#macro aws_contentnode_cf_deployment_generationcontract_application occurrence ]
    [@addDefaultGenerationContract subsets=[ "pregeneration", "prologue" ] /]
[/#macro]

[#macro aws_contentnode_cf_deployment_application occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources]

    [#local contentNodeId = resources["contentnode"].Id ]
    [#local pathObject = getContextPath(occurrence) ]

    [#local hubFound = false]

    [#local buildReference = getOccurrenceBuildReference(occurrence)]
    [#local buildUnit = getOccurrenceBuildUnit(occurrence)]

    [#local imageSource = solution.Image.Source]

    [#if imageSource == "url" ]
        [#local buildUnit = occurrence.Core.Name ]
    [/#if]

    [#if deploymentSubsetRequired("pregeneration", false)]
        [#if imageSource = "url" ]
            [@addToDefaultBashScriptOutput
                content=
                    getImageFromUrlScript(
                        regionId,
                        productName,
                        environmentName,
                        segmentName,
                        occurrence,
                        solution.Image["Source:url"].Url,
                        "contentnode",
                        "contentnode.zip",
                        solution.Image["Source:url"].ImageHash,
                        true
                    )
            /]
        [/#if]
    [/#if]

    [#list solution.Links?values as link]
        [#if link?is_hash]
            [#local linkTarget = getLinkTarget(occurrence, link) ]

            [@debug message="Link Target" context=linkTarget enabled=false /]

            [#if !linkTarget?has_content]
                [#continue]
            [/#if]

            [#local linkTargetCore = linkTarget.Core ]
            [#local linkTargetConfiguration = linkTarget.Configuration ]
            [#local linkTargetAttributes = linkTarget.State.Attributes ]

            [#switch linkTargetCore.Type]
                [#case "external"]
                [#case "contenthub"]

                    [#local hubFound = true]

                    [#if deploymentSubsetRequired("prologue", false)]
                        [@addToDefaultBashScriptOutput
                            content=
                            [
                                "function get_contentnode_file_${core.RawId}() {",
                                "  # Fetch the spa zip file",
                                "  copyFilesFromBucket" + " " +
                                    regionId + " " +
                                    getRegistryEndPoint("contentnode", occurrence) + " " +
                                    formatRelativePath(
                                        getRegistryPrefix("contentnode", occurrence),
                                        getOccurrenceBuildProduct(occurrence, productName),
                                        getOccurrenceBuildScopeExtension(occurrence),
                                        buildUnit,
                                        buildReference
                                    ) +
                                    r'  "${tmpdir}" || return $?',
                                "  # Sync with the contentnode",
                                "  copy_contentnode_file \"$\{tmpdir}/contentnode.zip\" " +
                                        "\"" + linkTargetAttributes.ENGINE + "\" " +
                                        "\"" +    linkTargetAttributes.REPOSITORY + "\" " +
                                        "\"" +    linkTargetAttributes.PREFIX + "\" " +
                                        "\"" +    pathObject + "\" " +
                                        "\"" +    linkTargetAttributes.BRANCH + "\" " +
                                        "\"replace\" || return $? ",
                                "}",
                                "get_contentnode_file_${core.RawId} || exit $?"
                            ]
                        /]
                    [/#if]
                [#break]
            [/#switch]
        [/#if]
    [/#list]

    [#if ! hubFound ]
        [@fatal
            message="Could not find contenthub for content node"
            context={
                "ContentNode" : core.RawName,
                "Links" : solution.Links
            }
            detail="Check your links for contenthubs and make sure they are deployed"
        /]
    [/#if]
[/#macro]
