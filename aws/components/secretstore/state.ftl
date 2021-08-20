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
