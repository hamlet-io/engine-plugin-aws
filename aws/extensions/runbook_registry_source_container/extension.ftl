[#ftl]

[@addExtension
    id="runbook_registry_source_container"
    aliases=[
        "_runbook_registry_source_container"
    ]
    description=[
        "Get the name of the container image to pull from the docker image registry"
    ]
    supportedTypes=[
        RUNBOOK_STEP_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_runbook_registry_source_container_runbook_setup occurrence ]

    [#local imageLink = (_context.Links["image"])!{}]
    [#if ! imageLink?has_content ]
        [#return]
    [/#if]
    [#local image = imageLink.State.Images[_context.Inputs["input:ImageId"]] ]

    [#assign _context = mergeObjects(
        _context,
        {
            "TaskParameters" : {
                "Image": (_context.Inputs["input:Reference"] == "_latest")?then(
                        image.ImageLocation,
                        (image.ImageLocation)?replace(image.Reference, _context.Inputs["input:Reference"])
                    )
            }
        }
    )]

[/#macro]
