[#ftl]
[#macro aws_contentnode_cf_deployment_generationcontract_application occurrence ]
    [@addDefaultGenerationContract subsets=["deploymentcontract", "pregeneration", "prologue" ] /]
[/#macro]

[#macro aws_contentnode_cf_deployment_deploymentcontract occurrence ]
    [@addDefaultAWSDeploymentContract prologue=true stack=false /]
[/#macro]

[#macro aws_contentnode_cf_deployment_application occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources]
    [#local image =  getOccurrenceImage(occurrence)]

    [#local contentNodeId = resources["contentnode"].Id ]
    [#local pathObject = getContextPath(occurrence) ]

    [#local hubFound = false]

    [#if deploymentSubsetRequired("pregeneration", false) && image.Source == "url" ]
        [@addToDefaultBashScriptOutput
            content=getAWSImageFromUrlScript(image, true)
        /]
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
                                    getRegion() + " " +
                                    image.ImageLocation?keep_after("s3://")?keep_before("/") + " " +
                                    image.ImageLocation?keep_after("s3://")?keep_after("/") + " " +
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
