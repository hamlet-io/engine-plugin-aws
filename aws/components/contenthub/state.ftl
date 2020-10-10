[#ftl]
[#-- Resources --]
[#assign HAMLET_CONTENTHUB_HUB_RESOURCE_TYPE = "contenthub"]

[#macro aws_contenthub_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]

    [#if core.External!false ]
        [#local engine = (occurrence.State.Attributes["ENGINE"])!"HamletFatal: Engine not found" ]
        [#local repoistory = (occurrence.State.Attributes["REPOSITORY"])!"HamletFatal: Repository not found" ]
        [#local branch = (occurrence.State.Attributes["BRANCH"])!"HamletFatal: Branch not found" ]
        [#local prefix = (occurrence.State.Attributes["PREFIX"])!"HamletFatal: Prefix not found" ]

        [#assign componentState =
            {
                "Attributes" : {
                    "ENGINE" : engine,
                    "REPOSITORY" : repoistory,
                    "BRANCH" : branch,
                    "PREFIX" : prefix
                }
            }
        ]
    [#else]
        [#local solution = occurrence.Configuration.Solution]
        [#local id = formatResourceId(HAMLET_CONTENTHUB_HUB_RESOURCE_TYPE, core.Id)]

        [#local engine = solution.Engine ]
        [#local repoistory = solution.Repository ]
        [#local branch = solution.Branch ]
        [#local prefix = solution.Prefix ]

        [#assign componentState =
            {
                "Resources" : {
                    "contenthub" : {
                        "Id" : id,
                        "Type" : HAMLET_CONTENTHUB_HUB_RESOURCE_TYPE,
                        "Deployed" : true
                    }
                },
                "Attributes" : {
                    "ENGINE" : engine,
                    "REPOSITORY" : repoistory,
                    "BRANCH" : branch,
                    "PREFIX" : prefix
                },
                "Roles" : {
                    "Inbound" : {},
                    "Outbound" : {}
                }
            }
        ]
    [/#if]
[/#macro]
