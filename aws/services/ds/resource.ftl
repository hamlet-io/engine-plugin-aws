[#ftl]

[#assign DIRECTORY_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_DIRECTORY_RESOURCE_TYPE
    mappings=DIRECTORY_OUTPUT_MAPPINGS
/]

[#macro createDSInstance id name
    type
    size
    masterPassword=""
    enableSSO=false
    fqdName=""
    shortName=""
    vpcSettings=""
]
    [@cfResource
    id=id
    type="AWS::DirectoryService::"+type
    properties=
        {
            "Password": masterPassword,
            "EnableSso": enableSSO,
            "Name": fqdName,
            "VpcSettings": vpcSettings
        } +
        attributeIfContent(
            "Edition",
            (type="MicrosoftAD")?then(size,"")
        ) +
        attributeIfContent(
            "ShortName",
            shortName
        ) +
        attributeIfContent(
            "Size",
            (type="MicrosoftAD")?then("",size)
        )
    outputs=
        DIRECTORY_OUTPUT_MAPPINGS
    /]
[/#macro]
