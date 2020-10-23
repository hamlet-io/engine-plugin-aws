[#ftl]

[#-- Resources --]
[#assign AWS_IAM_POLICY_RESOURCE_TYPE="policy" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_IDENTITY_SERVICE
    resource=AWS_IAM_POLICY_RESOURCE_TYPE
/]
[#assign AWS_IAM_MANAGED_POLICY_RESOURCE_TYPE = "managedPolicy" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_IDENTITY_SERVICE
    resource=AWS_IAM_MANAGED_POLICY_RESOURCE_TYPE
/]
[#assign AWS_IAM_ROLE_RESOURCE_TYPE="role" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_IDENTITY_SERVICE
    resource=AWS_IAM_ROLE_RESOURCE_TYPE
/]
[#assign AWS_IAM_USER_RESOURCE_TYPE="user"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_IDENTITY_SERVICE
    resource=AWS_IAM_USER_RESOURCE_TYPE
/]
[#assign AWS_IAM_SERVICE_LINKED_ROLE_RESOURCE_TYPE="serviceLinkedRole" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_IDENTITY_SERVICE
    resource=AWS_IAM_SERVICE_LINKED_ROLE_RESOURCE_TYPE
/]

[#function formatPolicyId ids...]
    [#return formatResourceId(
                AWS_IAM_POLICY_RESOURCE_TYPE,
                ids)]
[/#function]

[#function formatDependentPolicyId resourceId extensions...]
    [#return formatDependentResourceId(
                AWS_IAM_POLICY_RESOURCE_TYPE,
                resourceId,
                extensions)]
[/#function]

[#function formatComponentPolicyId tier component extensions...]
    [#return formatComponentResourceId(
                AWS_IAM_POLICY_RESOURCE_TYPE,
                tier,
                component,
                extensions)]
[/#function]

[#function formatManagedPolicyId ids... ]
    [#return formatResourceId(
                AWS_IAM_MANAGED_POLICY_RESOURCE_TYPE,
                ids
    )]
[/#function]

[#function formatDependentManagedPolicyId resourceId extensions... ]
    [#return formatResourceId(
                AWS_IAM_MANAGED_POLICY_RESOURCE_TYPE,
                resourceId,
                extensions
    )]
[/#function]

[#function formatRoleId ids...]
    [#return formatResourceId(
                AWS_IAM_ROLE_RESOURCE_TYPE,
                ids)]
[/#function]

[#function formatDependentRoleId resourceId extensions...]
    [#return formatDependentResourceId(
                AWS_IAM_ROLE_RESOURCE_TYPE,
                resourceId,
                extensions)]
[/#function]

[#function formatAccountRoleId type extensions...]
    [#return formatAccountResourceId(
                AWS_IAM_ROLE_RESOURCE_TYPE,
                type,
                extensions)]
[/#function]

[#function formatComponentRoleId tier component extensions...]
    [#return formatComponentResourceId(
                AWS_IAM_ROLE_RESOURCE_TYPE,
                tier,
                component,
                extensions)]
[/#function]


[#function formatAccountServiceLinkedRoleId type extensions...]
    [#return formatAccountResourceId(
                AWS_IAM_SERVICE_LINKED_ROLE_RESOURCE_TYPE,
                type,
                extensions)]
[/#function]

[#function formatServiceLinkedRoleArn trustedService roleName ]
    [#return
        formatGlobalArn(
            "iam"
            formatRelativePath(
                "role",
                trustedService,
                roleName
            )
        )
    ]
[/#function]
