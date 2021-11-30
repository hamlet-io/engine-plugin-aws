[#ftl]
[#macro aws_secretstore_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution ]

    [#assign componentState =
        {
            "Resources" : {
                "secretStore" : {
                    "Id" : core.Id,
                    "Name" : core.FullName,
                    "Deployed" : true
                }
            },
            "Attributes" : {
                "ENGINE" : solution.Engine
            },
            "Roles" : {
                "Inbound" : {
                },
                "Outbound" : {
                }
            }
        }
    ]
[/#macro]

[#macro aws_secret_cf_state occurrence parent={} ]
    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]

    [#local parentSolution = parent.Configuration.Solution]

    [#local resources = {}]
    [#local attributes = {}]
    [#local roles = {
        "Inbound" : {
        },
        "Outbound" : {}
    }]

    [#switch parentSolution.Engine ]
        [#case "aws:secretsmanager" ]

            [#local secretId = formatResourceId(AWS_SECRETS_MANAGER_SECRET_RESOURCE_TYPE, occurrence.Core.Id)]

            [#local baselineLinks = getBaselineLinks(occurrence, [ "Encryption"], true, false )]

            [#if baselineLinks?has_content ]
                [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
                [#local cmkKeyId = (baselineComponentIds["Encryption"]) ]
            [#else]
                [#local cmkKeyId = ""]
            [/#if]

            [#local resources = mergeObjects(
                resources,
                {
                    "secret" : {
                        "Id" : secretId,
                        "Name" : occurrence.Core.FullName,
                        "Type" : AWS_SECRETS_MANAGER_SECRET_RESOURCE_TYPE,
                        "cmkKeyId" : cmkKeyId
                    }
                }
            )]

            [#local attributes = mergeObjects(
                attributes,
                {
                    "SECRET_VALUE" : getExistingReference(secretId, SECRET_ATTRIBUTE_TYPE),
                    "ARN" : getExistingReference(secretId, ARN_ATTRIBUTE_TYPE),
                    "ENGINE" : parentSolution.Engine
                }
            )]

            [#local roles = mergeObjects(
                roles,
                {
                    "Outbound" : {
                        "default" : "read",
                        "read" : secretsManagerReadPermission(secretId, cmkKeyId)
                    }
                }
            )]
            [#break]
    [/#switch]

    [#assign componentState =
        {
            "Resources"  : resources,
            "Attributes" : attributes,
            "Roles" : roles
        }
    ]
[/#macro]
