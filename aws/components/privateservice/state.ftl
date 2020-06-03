[#ftl]

[#macro aws_privateservice_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local resources = {}]

    [#list solution.ConnectionAlerts as alertId,connectionAlert ]
        [#list connectionAlert.Links as linkId,link ]
            [#local resources +=
                {
                    "vpcEndpointNotification" + alertId + linkId : {
                        "Id" : formatId(
                            AWS_VPC_ENDPOINT_SERVICE_NOTIFICATION_RESOURCE_TYPE,
                            core.Id,
                            alertId,
                            linkId
                        ),
                        "Type" : AWS_VPC_ENDPOINT_SERVICE_NOTIFICATION_RESOURCE_TYPE
                    }
                }
            ]
        [/#list]
    [/#list]

    [#assign componentState =
        {
            "Resources" : {
                "vpcEndpointService" : {
                    "Id" : formatId(
                            AWS_VPC_ENDPOINT_SERVICE_RESOURCE_TYPE,
                            core.Id
                    ),
                    "Type" : AWS_VPC_ENDPOINT_SERVICE_RESOURCE_TYPE
                },
                "vpcEndpointServicePermission" : {
                    "Id" : formatId(
                            AWS_VPC_ENDPOINT_SERVICE_PERMISSION_RESOURCE_TYPE,
                            core.Id
                    ),
                    "Type" : AWS_VPC_ENDPOINT_SERVICE_PERMISSION_RESOURCE_TYPE
                }
            } +
            resources,
            "Attributes" : {
            },
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]
[/#macro]
