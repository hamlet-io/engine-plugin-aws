[#ftl]

[@addExtension
    id="runbook_registry_source_object"
    aliases=[
        "_runbook_registry_source_object"
    ]
    description=[
        "Format the registry parameter details for s3 based object"
    ]
    supportedTypes=[
        RUNBOOK_STEP_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_runbook_registry_source_object_runbook_setup occurrence ]

    [#local imageLink = (_context.Links["image"])!{}]
    [#if ! imageLink?has_content ]
        [#return]
    [/#if]
    [#local image = imageLink.State.Images[_context.Inputs["input:ImageId"]] ]

    [#assign _context = mergeObjects(
        _context,
        {
            "TaskParameters" : {
                "BucketName" : ((image.RegistryPath)!"")?replace("s3://", "")?keep_before("/"),
                "Object": ((image.RegistryPath)!"")?replace("s3://", "")?keep_after("/")
                    + (_context.Inputs["input:Reference"] == "_latest")?then(
                        image.Reference,
                        _context.Inputs["input:Reference"]
                    )
                    + (image.ImageFileName)!""
            }
        }
    )]

[/#macro]
