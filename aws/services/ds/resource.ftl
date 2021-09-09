[#ftl]

[#assign DIRECTORY_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ALIAS_ATTRIBUTE_TYPE : {
            "Attribute" : "Alias"
        },
        IP_ADDRESS_ATTRIBUTE_TYPE : {
            "Attribute" : "DnsIpAddresses"
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
    edition
    masterPassword=""
    enableSSO=false
    dsName=""
    shortName=""
    size=""
]
    [@cfResource
    id=id
    type="AWS::DirectoryService::"+type
    properties=
        {
            "Password": masterPassword,
            "EnableSso": enableSSO,
            "Name": dsName,
            "VpcSettings" : VpcSettings
        } +
        attributeIfContent(
            "Edition",
            edition
        ) +
        attributeIfContent(
            "ShortName",
            shortName
        ) +
        attributeIfContent(
            "Size",
            size
        )
    outputs=
        DIRECTORY_OUTPUT_MAPPINGS
    /]
[/#macro]
