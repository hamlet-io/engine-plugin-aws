[#ftl]

[#assign CFN_STACK_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        DNS_ATTRIBUTE_TYPE : {
            "Attribute" : "DomainName"
        },
        ARN_ATTRIBUTE_TYPE : {
            "Attribute" : "Arn"
        },
        URL_ATTRIBUTE_TYPE : {
            "Attribute" : "Url"
        },
        NAME_ATTRIBUTE_TYPE : {
            "Attribute" : "Name"
        },
        IP_ADDRESS_ATTRIBUTE_TYPE : {
            "Attribute" : "IPAddress"
        },
        KEY_ATTRIBUTE_TYPE : {
            "Attribute" : "Key"
        },
        PORT_ATTRIBUTE_TYPE : {
            "Attribute" : "Port"
        },
        USERNAME_ATTRIBUTE_TYPE : {
            "Attribute" : "UserName"
        },
        PASSWORD_ATTRIBUTE_TYPE : {
            "Attribute" : "Password"
        },
        REGION_ATTRIBUTE_TYPE : {
            "Value" : { "Ref" : "AWS::Region" }
        }
    }
]


[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_CLOUDFORMATION_STACK_RESOURCE_TYPE
    mappings=CFN_STACK_OUTPUT_MAPPINGS
/]

[#macro createCFNNestedStack id parameters tags tempalteUrl outputs dependencies="" ]
    [@cfResource
        id=id
        type="AWS::CloudFormation::Stack"
        properties={
            "Parameters" : parameters,
            "TemplateURL" : tempalteUrl,
            "Tags" : tags
        }
        outputs=outputs
        dependencies=dependencies
    /]
[/#macro]
