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
        outputs=
            {
                REFERENCE_ATTRIBUTE_TYPE : {
                    "UseRef" : true
                }
            } +
            outputs
        dependencies=dependencies
    /]
[/#macro]

[#assign CFN_CONDITION_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        RESULT_ATTRIBUTE_TYPE : {
            "Attribute" : "Data"
        }
    }]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_CLOUDFORMATION_WAIT_HANDLE_RESOURCE_TYPE
    mappings=CFN_STACK_OUTPUT_MAPPINGS
/]

[#macro createCFNWait conditionId handleId signalCount timeout=600 waitDependencies=[] ]

    [@cfResource
        id=conditionId
        type="AWS::CloudFormation::WaitCondition"
        properties={
            "Count" : signalCount,
            "Handle" : getReference(handleId),
            "Timeout" : timeout
        }
        dependencies=waitDependencies
    /]

    [@cfResource
        id=handleId
        type="AWS::CloudFormation::WaitConditionHandle"
        properties={}
    /]

[/#macro]
