[#ftl]

[#macro aws_healthcheck_cf_state occurrence parent={} ]
    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]

    [#local segmentSeedId = formatSegmentSeedId() ]
    [#local segmentSeed = getExistingReference(segmentSeedId)]

    [#local resources = {}]
    [#local attributes = {}]
    [#local roles = {
        "Inbound" : {},
        "Outbound" : {}
    }]

    [#switch solution.Engine ]
        [#case "Simple" ]
            [#local resources = {
                "healthcheck" : {
                    "Id" : formatResourceId(AWS_ROUTE53_HEALTHCHECK_RESOURCE_TYPE, core.Id),
                    "Name" : core.FullName,
                    "Type" : AWS_ROUTE53_HEALTHCHECK_RESOURCE_TYPE,
                    "Monitored" : true
                }
            }]
            [#break]
        [#case "Complex"]

            [#local canaryId = formatResourceId(AWS_CLOUDWATCH_CANARY_RESOURCE_TYPE, core.Id)]
            [#local securityGroupId = formatDependentSecurityGroupId(canaryId)]

            [#local resources += {
                "canary" : {
                    "Id" : formatResourceId(AWS_CLOUDWATCH_CANARY_RESOURCE_TYPE, core.Id),
                    [#-- Name must be less than 21 chars --]
                    "Name" : concatenate([
                                    segmentSeed?truncate_c(5, ""),
                                    (core.Version.Name)?split("")?reverse?join("")?truncate_c(5, "")?split("")?reverse?join(""),
                                    (core.Instance.Name)?split("")?reverse?join("")?truncate_c(5, "")?split("")?reverse?join(""),
                                    (core.Component.Name)?split("")?reverse?join("")?truncate_c(5, "")?split("")?reverse?join("")
                                ],
                                "_")
                                ?lower_case,
                    "TagName" : core.FullName,
                    "Type" : AWS_CLOUDWATCH_CANARY_RESOURCE_TYPE,
                    "Monitored" : true
                },
                "role" : {
                    "Id" : formatDependentRoleId(canaryId),
                    "Type" : AWS_IAM_ROLE_RESOURCE_TYPE,
                    "IncludeInDeploymentState" : false
                }
            } +
            attributeIfTrue(
                "securityGroup",
                solution.NetworkAccess,
                {
                    "Id" : securityGroupId,
                    "Name" : core.FullName,
                    "Type" : AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE
                }
            )]

            [#local roles += {
                "Inbound" : {
                } +
                attributeIfTrue(
                    "networkacl",
                    solution.NetworkAccess,
                    {
                        "SecurityGroups" : securityGroupId,
                        "Description" : core.FullName
                    }
                )
            }]
    [/#switch]

    [#assign componentState =
        {
            "Resources" : resources,
            "Attributes" : attributes,
            "Roles" : roles
        }
    ]
[/#macro]
