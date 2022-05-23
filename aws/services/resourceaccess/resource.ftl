[#ftl]

[#macro createResourceAccessShare
            id
            name
            allowNonOrgPrincipals
            principals
            resourceArns
            tags={}
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
        tags=tags
    /]
[/#macro]
