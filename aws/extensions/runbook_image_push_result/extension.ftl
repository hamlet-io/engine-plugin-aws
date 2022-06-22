[#ftl]

[@addExtension
    id="runbook_image_push_result"
    aliases=[
        "_runbook_image_push_result"
    ]
    description=[
        "generate a result output for an image push"
    ]
    supportedTypes=[
        RUNBOOK_STEP_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_runbook_image_push_result_runbook_setup occurrence ]

    [#local image = (_context.Links["image"])!{}]
    [#if ! image?has_content]
        [#return]
    [/#if]

    [#assign _context = mergeObjects(
        _context,
        {
            "TaskParameters" : {
                "Value" : {
                    "Value": getJSON(
                        {
                            "Name": image.State.Resources.image.Name,
                            "RegistryType" : image.State.Resources.image.RegistryType,
                            "Format" : image.Configuration.Solution.Format,
                            "Reference": "__input:Reference__",
                            "Tag": "__input:Tag__",
                            "s3" : {
                                "LocalPath" : "__input:ImagePath__",
                                "RemotePath": "__output:registry_s3_push:s3_path__"
                            },
                            "docker" : {
                                "LocalDockerImage": "__input:DockerImage__",
                                "RemoteDockerRegistryRef" : "__output:registry_docker_push:destination_image__",
                                "RemoteDockerRegistryTag" : "__output:registry_docker_push_tag:destination_image__"
                            }
                        }
                    )
                }
            }
        }
    )]
[/#macro]
