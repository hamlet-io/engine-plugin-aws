[#ftl]

[@addExtension
    id="runbook_registry_destination_object"
    aliases=[
        "_runbook_registry_destination_object"
    ]
    description=[
        "Format the registry parameter details for s3 based object"
    ]
    supportedTypes=[
        RUNBOOK_STEP_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_runbook_registry_destination_object_runbook_setup occurrence ]

    [#local image = (_context.Links["image"])!{}]
    [#if ! image?has_content]
        [#return]
    [/#if]

    [#assign _context = mergeObjects(
        _context,
        {
            "TaskParameters" : {
                "BucketName" : ((image.State.Resources["image"].Location)!"")?replace("s3://", "")?keep_before("/"),
                "Object": ((image.State.Resources["image"].Registry)!"")?replace("s3://", "")?keep_after("/")  + "/__input:Reference__/" +  (image.State.Resources["image"].ImageFileName)!""
            }
        }
    )]

[/#macro]
