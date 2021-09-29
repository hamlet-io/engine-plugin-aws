[#ftl]
[#macro aws_dataset_cf_deployment_generationcontract_application occurrence ]
    [@addDefaultGenerationContract subsets=[ "pregeneration", "prologue" ] /]
[/#macro]

[#macro aws_dataset_cf_deployment_application occurrence ]

    [#local solution = occurrence.Configuration.Solution]

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
                        getRegion(),
                        productName,
                        environmentName,
                        segmentName,
                        occurrence,
                        solution.Image["Source:url"].Url,
                        "dataset",
                        "dataset.zip",
                        solution.Image["Source:url"].ImageHash,
                        true
                    )
            /]
        [/#if]
    [/#if]

    [#if deploymentSubsetRequired("prologue", false)]
        [@addToDefaultBashScriptOutput
            [
                r'info "Dataset deployment. Nothing to do"'
            ]
        /]
    [/#if]
[/#macro]
