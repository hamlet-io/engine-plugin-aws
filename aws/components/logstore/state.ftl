[#ftl]
[#macro aws_logstore_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution ]

    [#local logGroupId = formatLogGroupId(core.Id)]
    [#local logGroupName = formatAbsolutePath(getContextPath( occurrence, solution.Path))]

    [#assign componentState =
        {
            "Resources" : {
                "lg" : {
                    "Id" : logGroupId,
                    "Name" : logGroupName,
                    "Type" : AWS_CLOUDWATCH_LOG_GROUP_RESOURCE_TYPE
                }
            },
            "Attributes" : {
                "NAME" : logGroupName,
                "ARN" : getArn(logGroupId)
            },
            "Roles" : {
                "Inbound" : {
                },
                "Outbound" : {
                    "default" : "read",
                    "write": cwLogsProducePermission(logGroupName),
                    "read" : cwLogsReadPermission(logGroupName)
                }
            }
        }
    ]
[/#macro]
