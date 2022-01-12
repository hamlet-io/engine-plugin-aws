[#ftl]

[@addExtension
    id="runbook_get_vpc_id"
    aliases=[
        "_runbook_get_vpc_id"
    ]
    description=[
        "Use a host on the network to get the vpcId"
    ]
    supportedTypes=[
        RUNBOOK_STEP_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_runbook_get_vpc_id_runbook_setup occurrence ]

    [#local host = _context.Links["host"]]

    [#local occurrenceNetwork = getOccurrenceNetwork(_context.Links["host"]) ]
    [#local networkLink = occurrenceNetwork.Link!{} ]
    [#local networkLinkTarget = getLinkTarget(_context.Links["host"], networkLink ) ]
    [#local vpcId = networkLinkTarget.State.Attributes["VPC_ID"]]

    [#assign _context = mergeObjects(
        _context,
        {
            "TaskParameters" : {
                "VpcId" : vpcId
            }
        }
    )]
[/#macro]
