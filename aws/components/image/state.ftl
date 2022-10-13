[#ftl]

[#macro aws_image_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local image = constructAWSImageResource(occurrence, solution.Format, solution, "default")]

    [#local resources = {} +
        attributeIfTrue(
            "containerRepository",
            (image.default.RegistryType == "docker"),
            {
                "Id": formatResourceId(AWS_ECR_REPOSITORY_RESOURCE_TYPE, occurrence.Core.Id),
                "Name": image.default.RegistryPath?keep_after("/"),
                "Type": AWS_ECR_REPOSITORY_RESOURCE_TYPE
            }
        )]

    [#assign componentState =
        {
            "Images": image,
            "Resources" : resources,
            "Attributes" : {
                "LOCATION": image.default.ImageLocation,
                "REFERENCE" : (image.default.Reference)!"",
                "TAG": (image.default.Tag)!""
            }
        }
    ]
[/#macro]
