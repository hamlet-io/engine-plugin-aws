[#ftl]
[#macro aws_dataset_cf_deployment_generationcontract_application occurrence ]
    [@addDefaultGenerationContract subsets=[ "pregeneration", "prologue" ] /]
[/#macro]

[#macro aws_dataset_cf_deployment_application occurrence ]

    [#local solution = occurrence.Configuration.Solution]
    [#local image =  getOccurrenceImage(occurrence)]

    [#if deploymentSubsetRequired("pregeneration", false) && image.Source == "url" ]
        [@addToDefaultBashScriptOutput
            content=getAWSImageFromUrlScript(image, true)
        /]
    [/#if]

    [#if deploymentSubsetRequired("prologue", false)]
        [@addToDefaultBashScriptOutput
            [
                r'info "Dataset deployment. Nothing to do"'
            ]
        /]
    [/#if]
[/#macro]
