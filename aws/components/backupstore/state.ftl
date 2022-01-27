[#ftl]

[#macro aws_backupstore_cf_state occurrence parent={} ]

    [#local core = occurrence.Core]

    [#local vaultId = formatResourceId(AWS_BACKUP_VAULT_RESOURCE_TYPE, core.Id)]

    [#assign componentState =
        {
            "Resources" : {
                "vault" : {
                    "Id" : vaultId,
                    "Name" : formatComponentFullName(core.Tier, core.Component, occurrence),
                    "Type" : AWS_BACKUP_VAULT_RESOURCE_TYPE
                },
                "role" : {
                    "Id" : formatResourceId(AWS_IAM_ROLE_RESOURCE_TYPE, core.Id),
                    "Type" : AWS_IAM_ROLE_RESOURCE_TYPE,
                    "IncludeInDeploymentState" : false
                }
            },
            "Attributes" : {
                "ARN" : getExistingReference(vaultId, ARN_ATTRIBUTE_TYPE)
            },
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]
[/#macro]

[#macro aws_backupstoreregime_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution ]

    [#assign componentState =
        {
            "Resources" : {
                "plan" : {
                    "Id" : formatResourceId(AWS_BACKUP_PLAN_RESOURCE_TYPE, core.Id),
                    "Name" : formatComponentFullName(core.Tier, core.Component, occurrence),
                    "Type" : AWS_BACKUP_PLAN_RESOURCE_TYPE
                },
                "selection" : {
                    "Id" : formatResourceId(AWS_BACKUP_SELECTION_RESOURCE_TYPE, core.Id),
                    "Name" : formatComponentFullName(core.Tier, core.Component, occurrence),
                    "Type" : AWS_BACKUP_SELECTION_RESOURCE_TYPE
                }
            },
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        } +
        attributeIfTrue(
            "Attributes",
            (solution.Targets.Tag.Enabled)!false,
            {
                "TAG_NAME" : ["backup", core.SubComponent.Name]?join(":"),
                "TAG_VALUE" : formatComponentFullName(core.Tier, core.Component, occurrence)
            }
        )
    ]
[/#macro]
