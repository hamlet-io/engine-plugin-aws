[#ftl]

[#macro aws_datavolume_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local zoneResources = {} ]

    [#local zones = getZones()?filter(zone -> solution.Zones?seq_contains(zone.Id) || solution.Zones?seq_contains("_all")) ]
    [#list multiAZ?then(zones, [zones[0]]) as zone ]
        [#local zoneResources +=
            {
                zone.Id : {
                    "ebsVolume" : {
                        "Id" :  formatResourceId(AWS_EC2_EBS_RESOURCE_TYPE, core.Id, zone.Id ),
                        "Name" : core.FullName,
                        "Type" : AWS_EC2_EBS_RESOURCE_TYPE
                    }
                }
            }
        ]
    [/#list]

    [#assign componentState =
        {
            "Resources" : {
                "manualSnapshot" : {
                    "Id" : formatResourceId( AWS_EC2_EBS_MANUAL_SNAPSHOT_RESOURCE_TYPE, core.Id),
                    "Type" : AWS_EC2_EBS_MANUAL_SNAPSHOT_RESOURCE_TYPE
                },
                "Zones" : zoneResources
            },
            "Attributes" : {
                "VOLUME_NAME" : core.FullName,
                "ENGINE" : solution.Engine
            }
        }
    ]
[/#macro]
