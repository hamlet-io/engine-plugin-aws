[#ftl]

[@addExtension
    id="runbook_registry_destination_image"
    aliases=[
        "_runbook_registry_destination_image"
    ]
    description=[
        "Format the registry image for docker containers"
    ]
    supportedTypes=[
        RUNBOOK_STEP_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_runbook_registry_destination_image_runbook_setup occurrence ]

    [#local image = (_context.Links["image"])!{}]
    [#if ! image?has_content]
        [#return]
    [/#if]

    [#assign _context = mergeObjects(
        _context,
        {
            "TaskParameters" : {
                "DestinationImage" : ((image.State.Resources["image"].Registry)!"") + ":__input:Reference__"
            }
        }
    )]

[/#macro]
