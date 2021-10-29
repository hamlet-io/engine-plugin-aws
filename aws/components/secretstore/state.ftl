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

    [#switch parentSolution.Engine ]
        [#case "aws:secretsmanager" ]

            [#local secretId = formatResourceId(AWS_SECRETS_MANAGER_SECRET_RESOURCE_TYPE, occurrence.Core.Id)]

            [#local resources = mergeObjects(
                resources,
                {
                    "secret" : {
                        "Id" : secretId,
                        "Name" : occurrence.Core.FullName,
                        "Type" : AWS_SECRETS_MANAGER_SECRET_RESOURCE_TYPE
                    }
                }
            )]

            [#local attributes = mergeObjects(
                attributes,
                {
                    "SECRET_VALUE" : getExistingReference(secretId, SECRET_ATTRIBUTE_TYPE),
                    "ARN" : getExistingReference(secretId, ARN_ATTRIBUTE_TYPE)
                }
            )]
            [#break]
    [/#switch]

    [#assign componentState =
        {
            "Resources"  : resources,
            "Attributes" : attributes,
            "Roles" : {
                "Inbound" : {
                },
                "Outbound" : {
                }
            }
        }
    ]
[/#macro]
