[#ftl]

[@registerInputSeeder
    id=AWS_INPUT_SEEDER
    description="AWS provider inputs"
/]

[@addSeederToConfigPipeline
    stage=MASTERDATA_SHARED_INPUT_STAGE
    seeder=AWS_INPUT_SEEDER
/]

[@addSeederToConfigPipeline
    stage=FIXTURE_SHARED_INPUT_STAGE
    seeder=AWS_INPUT_SEEDER
/]

[@addSeederToConfigPipeline
    stage=NORMALISE_SHARED_INPUT_STAGE
    seeder=AWS_INPUT_SEEDER
/]

[@addSeederToConfigPipeline
    sources=[MOCK_SHARED_INPUT_SOURCE]
    stage=COMMANDLINEOPTIONS_SHARED_INPUT_STAGE
    seeder=AWS_INPUT_SEEDER

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

[#function aws_configseeder_masterdata filter state]

    [#if filterAttributeContainsValue(filter, "Provider", AWS_PROVIDER) ]
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
    [/#if]
    [#return state]

[/#function]

[#function aws_configseeder_fixture filter state]

    [#if filterAttributeContainsValue(filter, "Provider", AWS_PROVIDER) ]
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
    [/#if]
    [#return state]

[/#function]

[#function aws_configseeder_commandlineoptions_mock filter state]

    [#if filterAttributeContainsValue(filter, "Provider", AWS_PROVIDER) ]
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
    [#return state]
[/#function]

[#-- Normalise cloud formation stack files to output sets --]
[#function aws_configseeder_normalise filter state]

    [#-- disable this functionality for now --]
    [#-- TODO(mfl): enable this as part of updated output processing --]
    [#return state]

    [#if filterAttributeContainsValue(filter, "Provider", AWS_PROVIDER) ]
        [#local outputSets = [] ]

        [#list ((state.Intermediate.Stacks)![])?filter(s -> s.ContentsAsJSON.Stacks?has_content) as stackFile]

            [#-- Looks like a cloud formation stack file --]
            [#local level = stackFile.FileName?split('-')[0] ]

            [#list stackFile.ContentsAsJSON.Stacks?filter(s -> s.Outputs?has_content) as stack ]
                [#-- Normalise to a set of outputs --]

                [#local outputSet = {} ]

                [#if stack.Outputs?is_sequence ]
                    [#list stack.Outputs as output ]
                        [#local outputSet += {
                            output.OutputKey : output.OutputValue
                        }]
                    [/#list]
                [/#if]

                [#if stack.Outputs?is_hash ]
                    [#local outputSet = stack.Outputs ]
                [/#if]

                [#if outputSet?has_content ]
                    [#local outputSets += [ mergeObjects( { "Level" : level} , outputSet) ] ]
                [/#if]

            [/#list]
        [/#list]

        [#return
            combineEntities(
                state,
                {
                    "OutputSets" : outputSets
                },
                APPEND_COMBINE_BEHAVIOUR
            ) +
            {
                "Intermediate" : removeObjectAttributes(state.Intermediate!{}, "Stacks")
            }
        ]
    [/#if]
    [#return state]
[/#function]
