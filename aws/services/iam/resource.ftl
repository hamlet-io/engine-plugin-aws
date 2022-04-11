[#ftl]

[#function formatIAMArn resource account={ "Ref" : "AWS::AccountId" }]
    [#return
        formatGlobalArn(
            "iam",
            resource,
            account
        )
    ]
[/#function]

[#function formatAccountPrincipalArn account={ "Ref" : "AWS::AccountId" }]
    [#return
        formatIAMArn(
            "root",
            account
        )
    ]
[/#function]

[#macro createPolicy id name statements roles="" users="" groups="" dependencies=[] ]
    [@cfResource
        id=id
        type="AWS::IAM::Policy"
        properties=
            getPolicyDocument(statements, name) +
            attributeIfContent("Users", users, getReferences(users)) +
            attributeIfContent("Roles", roles, getReferences(roles))
        dependencies=dependencies
        outputs={}
    /]
[/#macro]

[#assign MANAGED_POLICY_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_IAM_MANAGED_POLICY_RESOURCE_TYPE
    mappings=MANAGED_POLICY_OUTPUT_MAPPINGS
/]

[#macro createManagedPolicy id name statements roles="" users="" groups="" dependencies=[] ]
    [@cfResource
        id=id
        type="AWS::IAM::ManagedPolicy"
        properties=
            {
                "Description" : formatName(id, name)
            } +
            getPolicyDocument(statements) +
            attributeIfContent("Users", users, getReferences(users)) +
            attributeIfContent("Roles", roles, getReferences(roles))
        dependencies=dependencies
        outputs=MANAGED_POLICY_OUTPUT_MAPPINGS
    /]
[/#macro]

[#function addInlinePolicyToSet policies id name statements ]
    [#if !statements?has_content]
        [#return policies]
    [/#if]
    [#return
        combineEntities(
            policies,
            {
                "Inline" : [
                    {
                        "Id" : id,
                        "Name" : name,
                        "Statements" : statements,
                        [#-- For checking if the policy needs to be split --]
                        "Size" : getJSON(getPolicyDocumentContent(statements))?length
                    }
                ]
            },
            APPEND_COMBINE_BEHAVIOUR
        )
    ]
[/#function]

[#function addCustomerManagedPolicyToSet policies id name statements ]
    [#if !statements?has_content]
        [#return policies]
    [/#if]
    [#return
        combineEntities(
            policies,
            {
                "CustomerManaged" : [
                    {
                        "Id" : id,
                        "Name" : name,
                        "Statements" : statements,
                        [#-- For checking if the policy needs to be split --]
                        "Size" : getJSON(getPolicyDocumentContent(statements))?length
                    }
                ]
            },
            APPEND_COMBINE_BEHAVIOUR
        )
    ]
[/#function]

[#function addAWSManagedPoliciesToSet policies arns=[] ]
    [#return
        combineEntities(
            policies,
            {
                "AWSManaged" : asArray(arns)
            },
            APPEND_COMBINE_BEHAVIOUR
        )
    ]
[/#function]

[#function adjustPolicySetForRole policies context="" ]

    [#local aggregateHardLimit = 10240 ]
    [#local aggregateWarnLimit = (aggregateHardLimit * 0.9)?floor ]
    [#local managedPolicySizeLimit = 6144 ]

    [#local inlineEntries = policies.Inline![] ]
    [#local managedEntries = policies.CustomerManaged![] ]

    [#local totalSize = 0 ]
    [#list inlineEntries as entry ]
        [#local totalSize += entry.Size]
    [/#list]

    [#if totalSize > aggregateHardLimit]
        [@warn
            message="Role inline policy size of " + totalSize + " exceeds the AWS limit of " + aggregateHardLimit
            context=context
            detail="Inline policies will be converted to managed policies and also split where they exceed the managed policy size limit of " + managedPolicySizeLimit
        /]

        [#list inlineEntries as entry ]
            [#local statementChunks = entry.Statements?chunk((entry.Statements?size / ((entry.Size/managedPolicySizeLimit)?ceiling))?ceiling) ]
            [#if statementChunks?size == 1 ]
                [@debug
                    message="Policy " + entry?counter + " converted to a managed policy without splitting"
                    context=context
                /]
                [#local managedEntries +=
                    [
                        entry +
                        {
                            "Id" : formatDependentManagedPolicyId(entry.Id)
                        }
                    ]
                ]
            [#else]
                [@debug
                    message="Policy " + entry?counter + " split into " + statementChunks?size + " chunks"
                    context=context
                /]
                [#list statementChunks as chunk]
                    [#local newEntry =
                        entry +
                        {
                            "Id" : formatDependentManagedPolicyId(entry.Id, valueIfTrue(chunk?counter?c, statementChunks?size > 1, "")),
                            "Statements" : chunk
                        }
                    ]
                    [@debug
                        message="Policy " + entry?counter + " chunk " + chunk?counter + " has a size of " + getJSON(newEntry.Statements)?length
                        context=context
                    /]
                    [#local managedEntries += [newEntry] ]
                    ]
                [/#list]
            [/#if]
        [/#list]
        [#return
            policies +
            {
                "Inline" : [],
                "CustomerManaged" : managedEntries
            }
        ]
    [/#if]

    [#if totalSize > aggregateWarnLimit]
        [@warn
            message="Role inline policy size of " + totalSize + " is close to the AWS limit of " + aggregateHardLimit
            context=context
            detail=detail
        /]
    [/#if]
    [#return policies]
[/#function]

[#macro createInlinePoliciesFromSet policies ]
    [#list policies.Inline![] as entry]
        [@createPolicy
            id=entry.Id
            name=entry.Name
            statements=entry.Statements
            roles=entry.Roles
            users=entry.Users
            groups=entry.Groups
            dependencies=entry.Dependencies
        /]
    [/#list]
[/#macro]

[#macro createCustomerManagedPoliciesFromSet policies ]
    [#list policies.CustomerManaged![] as entry]
        [@createManagedPolicy
            id=entry.Id
            name=entry.Name
            statements=entry.Statements
            roles=entry.Roles
            users=entry.Users
            groups=entry.Groups
            dependencies=entry.Dependencies
        /]
    [/#list]
[/#macro]

[#function getPolicyDependenciesFromSet policies ]
    [#return
        (policies.Inline![])?map(x -> x.Id) +
        (policies.CustomerManaged![])?map(x -> x.Id)
    ]
[/#function]

[#function getManagedPoliciesFromSet policies]
    [#return
        (policies.AWSManaged![]) +
        (policies.CustomerManaged![])?map(x -> getReference(x.Id, ARN_ATTRIBUTE_TYPE))
    ]
[/#function]

[#assign ROLE_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "Attribute" : "Arn"
        },
        NAME_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_IAM_ROLE_RESOURCE_TYPE
    mappings=ROLE_OUTPUT_MAPPINGS
/]

[#macro createRole
            id
            trustedServices=[]
            federatedServices=[]
            trustedAccounts=[]
            multiFactor=false
            condition={}
            path=""
            name=""
            managedArns=[]
            policies=[]
            dependencies=[]
            tags=[]
            ]

    [#local trustedAccountArns = [] ]
    [#list asArray(trustedAccounts) as trustedAccount]
        [#local trustedAccountArns +=
            [
                formatAccountPrincipalArn(trustedAccount)
            ]
        ]
    [/#list]

    [#-- Handle legacy account --]
    [#if tags?size = 0]
        [#local tags=getCfTemplateCoreTags(name) ]
    [/#if]

    [@cfResource
        id=id
        type="AWS::IAM::Role"
        properties=
            attributeIfTrue(
                "AssumeRolePolicyDocument",
                trustedServices?has_content || trustedAccountArns?has_content || federatedServices?has_content,
                getPolicyDocumentContent(
                    getPolicyStatement(
                        valueIfTrue(
                            [ "sts:AssumeRoleWithWebIdentity" ],
                            federatedServices?has_content,
                            [ "sts:AssumeRole" ]
                        ),
                        "",
                        attributeIfContent("Service", asArray(trustedServices)) +
                            attributeIfContent("AWS", asArray(trustedAccountArns)) +
                            attributeIfContent("Federated", asArray(federatedServices)),
                        valueIfTrue(
                            getMFAPresentCondition(),
                            multiFactor
                        ) +
                        condition
                    )
                )
            ) +
            attributeIfContent("ManagedPolicyArns", asArray(managedArns)) +
            attributeIfContent("Path", path) +
            attributeIfContent("RoleName", name) +
            attributeIfContent("Policies", asArray(policies))
        outputs=ROLE_OUTPUT_MAPPINGS
        dependencies=dependencies
        tags=tags
    /]
[/#macro]

[#assign USER_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "Attribute" : "Arn"
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_IAM_USER_RESOURCE_TYPE
    mappings=USER_OUTPUT_MAPPINGS
/]



[#macro createServiceLinkedRole id
        serviceName
        customSuffix=""
        description=""
        dependencies=[] ]

    [@cfResource
        id=id
        type="AWS::IAM::ServiceLinkedRole"
        properties={
            "AWSServiceName" : serviceName
        } +
        attributeIfContent(
            "CustomSuffix",
            customSuffix
        ) +
        attributeIfContent(
            "Description",
            description
        )
        dependencies=dependencies
    /]
[/#macro]

[#-- Check that service linked role exists --]
[#function isServiceLinkedRoleDeployed serviceName ]
    [#assign deployed = false ]
    [#list getReferenceData(SERVICEROLE_REFERENCE_TYPE) as id,ServiceRole ]
        [#if ServiceRole.ServiceName == serviceName ]
            [#assign deployed = getExistingReference( formatAccountServiceLinkedRoleId(id) )?has_content ]
        [/#if]
    [/#list]
    [#return deployed]
[/#function]

