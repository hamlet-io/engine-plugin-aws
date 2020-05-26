[#ftl]

[#macro createResourceAccessShare
            id
            name
            allowNonOrgPrincipals
            principals
            resourceArns
    ]

    [@cfResource
        id=id
        type="AWS::RAM::ResourceShare"
        properties=
            {
                "AllowExternalPrincipals" : allowNonOrgPrincipals,
                "Name" : name,
                "Principals" : principals,
                "ResourceArns" : resourceArns
            }
        tags=getCfTemplateCoreTags(name)
    /]
[/#macro]
