[#ftl]

[@addExtension
    id="runbook_registry_destination_image_tag"
    aliases=[
        "_runbook_registry_destination_image_tag"
    ]
    description=[
        "Format the registry image for docker containers"
    ]
    supportedTypes=[
        RUNBOOK_STEP_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_runbook_registry_destination_image_tag_runbook_setup occurrence ]

    [#local imageLink = (_context.Links["image"])!{}]
    [#if ! imageLink?has_content ]
        [#return]
    [/#if]
    [#local image = imageLink.State.Images[_context.Inputs["input:ImageId"]] ]

    [#assign _context = mergeObjects(
        _context,
        {
            "TaskParameters" : {
                "DestinationImage" : ((image.Registry)!"") + ":__input:Tag__"
            }
        }
    )]

[/#macro]
