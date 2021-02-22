[#ftl]

[@addInputSeeder
    id=AWS_INPUT_SEEDER
    description="AWS provider inputs"
/]

[@addSeederToInputStage
    inputStage=MASTERDATA_SHARED_INPUT_STAGE
    inputSeeder=AWS_INPUT_SEEDER
/]

[@addSeederToInputStage
    inputStage=MOCK_SHARED_INPUT_STAGE
    inputSeeder=AWS_INPUT_SEEDER
/]

[@addSeederToInputStage
    inputSources=[MOCK_SHARED_INPUT_SOURCE]
    inputStage=COMMANDLINEOPTIONS_SHARED_INPUT_STAGE
    inputSeeder=AWS_INPUT_SEEDER

/]

[#macro aws_inputloader path]
    [#assign aws_cmdb_regions =
        (
            getPluginTree(
                path,
                {
                    "AddStartingWildcard" : false,
                    "AddEndingWildcard" : false,
                    "MinDepth" : 1,
                    "MaxDepth" : 1,
                    "FilenameGlob" : "regions.json"
                }
            )[0].ContentsAsJSON
        )!{}
    ]
    [#assign aws_cmdb_masterdata =
        (
            getPluginTree(
                path,
                {
                    "AddStartingWildcard" : false,
                    "AddEndingWildcard" : false,
                    "MinDepth" : 1,
                    "MaxDepth" : 1,
                    "FilenameGlob" : "masterdata.json"
                }
            )[0].ContentsAsJSON
        )!{}
    ]
[/#macro]

[#function aws_inputseeder_masterdata filter state]

    [#if getFilterAttribute(filter, "Provider")?seq_contains(AWS_PROVIDER)]
        [#local requiredRegions =
            getArrayIntersection(
                getFilterAttribute(filter, "Region")
                aws_cmdb_regions?keys
            )
        ]
        [#if requiredRegions?has_content]
            [#local regions = getObjectAttributes(aws_cmdb_regions, requiredRegions) ]
        [#else]
            [#local regions = aws_cmdb_regions]
        [/#if]
        [#return
            mergeObjects(
                state,
                {
                    "Masterdata" :
                        aws_cmdb_masterdata +
                        {
                            "Regions" : regions
                        }
                }
            )
        ]
    [#else]
        [#return state]
    [/#if]

[/#function]

[#function aws_inputseeder_mock filter state]

    [#if getFilterAttribute(filter, "Provider")?seq_contains(AWS_PROVIDER)]
        [#return
            mergeObjects(
                state,
                {
                    "Blueprint" :
                        {
                            "Account": {
                                "Region": "ap-southeast-2",
                                "ProviderId": "0123456789"
                            },
                            "Product": {
                                "Region": "ap-southeast-2"
                            }
                        }
                }
            )
        ]
    [#else]
        [#return state]
    [/#if]

[/#function]

[#function aws_inputseeder_commandlineoption_mock filter state]

    [#if getFilterAttribute(filter, "Provider")?seq_contains(AWS_PROVIDER)]
        [#return
            mergeObjects(
                state,
                {
                    "CommandLineOptions" : {
                        "Regions" : {
                            "Segment" : "ap-southeast-2",
                            "Account" : "ap-southeast-2"
                        }
                    }
                }
            )
        ]
    [/#if]
[/#function]
