[#ftl]

[@addExtension
    id="runbook_image_pull_result"
    aliases=[
        "_runbook_image_pull_result"
    ]
    description=[
        "generate a result output for an image pull"
    ]
    supportedTypes=[
        RUNBOOK_STEP_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_runbook_image_pull_result_runbook_setup occurrence ]
    [#local imageLink = (_context.Links["image"])!{}]
    [#if ! imageLink?has_content ]
        [#return]
    [/#if]
    [#local image = imageLink.State.Images[_context.Inputs["input:ImageId"]] ]

    [#assign _context = mergeObjects(
        _context,
        {
            "TaskParameters" : {
                "Value" : {
                    "Value": getJSON(
                        {
                            "Name": (image.Name)!"",
                            "RegistryType" : (image.RegistryType)!"",
                            "Format" : (imageLink.Configuration.Solution.Format)!"",
                            "Reference": "__input:Reference__",
                            "Tag": "__input:Tag__",
                            "s3" : {
                                "LocalPath" : "__input:ImagePath__",
                                "RemotePath": "__output:registry_s3_pull:s3_path__"
                            },
                            "docker" : {
                                "ImageName" : "${image.RegistryPath}:" + (_context.Inputs["input:Reference"] == "_latest")?then(image.Reference, "__input:Reference__")
                            }
                        }
                    )
                }
            }
        }
    )]
[/#macro]
