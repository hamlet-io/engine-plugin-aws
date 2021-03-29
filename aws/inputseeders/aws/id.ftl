[#ftl]

[@registerInputSeeder
    id=AWS_INPUT_SEEDER
    description="AWS provider inputs"
/]

[@registerInputTransformer
    id=AWS_INPUT_SEEDER
    description="AWS provider inputs"
/]

[@addSeederToConfigPipeline
    sources=[MOCK_SHARED_INPUT_SOURCE]
    stage=COMMANDLINEOPTIONS_SHARED_INPUT_STAGE
    seeder=AWS_INPUT_SEEDER
/]

[@addSeederToConfigPipeline
    stage=MASTERDATA_SHARED_INPUT_STAGE
    seeder=AWS_INPUT_SEEDER
/]

[@addSeederToConfigPipeline
    stage=FIXTURE_SHARED_INPUT_STAGE
    seeder=AWS_INPUT_SEEDER
/]

[@addTransformerToConfigPipeline
    stage=NORMALISE_SHARED_INPUT_STAGE
    transformer=AWS_INPUT_SEEDER
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
            getMatchingFilterAttributeValues(
                filter,
                "Region",
                aws_cmdb_regions?keys
            )
        ]
        [#if requiredRegions?has_content]
            [#local regions = getObjectAttributes(aws_cmdb_regions, requiredRegions) ]
        [#else]
            [#local regions = aws_cmdb_regions]
        [/#if]
        [#return
            addToConfigPipelineClass(
                state,
                BLUEPRINT_CONFIG_INPUT_CLASS,
                aws_cmdb_masterdata +
                {
                    "Regions" : regions
                },
                MASTERDATA_SHARED_INPUT_STAGE
            )
        ]
    [/#if]
    [#return state]

[/#function]

[#function aws_configseeder_fixture filter state]

    [#if filterAttributeContainsValue(filter, "Provider", AWS_PROVIDER) ]
        [#return
            addToConfigPipelineClass(
                state,
                BLUEPRINT_CONFIG_INPUT_CLASS,
                {
                    "Account": {
                        "Region": "ap-southeast-2",
                        "ProviderId": "0123456789"
                    },
                    "Product": {
                        "Region": "ap-southeast-2"
                    }
                },
                FIXTURE_SHARED_INPUT_STAGE
            )
        ]
    [/#if]
    [#return state]

[/#function]

[#function aws_configseeder_commandlineoptions_mock filter state]

    [#if filterAttributeContainsValue(filter, "Provider", AWS_PROVIDER) ]
        [#return
            addToConfigPipelineClass(
                state,
                COMMAND_LINE_OPTIONS_CONFIG_INPUT_CLASS,
                {
                    "Regions" : {
                        "Segment" : "ap-southeast-2",
                        "Account" : "ap-southeast-2"
                    }
                }
            )
        ]
    [/#if]
    [#return state]
[/#function]

[#-- Normalise cloud formation stack files to state point sets --]
[#function aws_configtransformer_normalise filter state]

    [#if filterAttributeContainsValue(filter, "Provider", AWS_PROVIDER) ]

        [#-- Anything to process? --]
        [#local stackFiles =
            getConfigPipelineClassCacheForStage(
                state,
                STATE_CONFIG_INPUT_CLASS,
                CMDB_SHARED_INPUT_STAGE
            )![]
        ]

        [#-- Normalise each stack to a point set --]
        [#local pointSets = [] ]

        [#-- Looks like format from aws cli cloudformation describe-stacks command? --]
        [#-- TODO(mfl) Remove check for .Content[0] once dynamic CMDB loading operational --]
        [#list stackFiles?filter(s -> ((s.ContentsAsJSON!s.Content[0]).Stacks)?has_content) as stackFile]
            [#list (stackFile.ContentsAsJSON!stackFile.Content[0]).Stacks?filter(s -> s.Outputs?has_content) as stack ]
                [#local pointSet = {} ]

                [#if stack.Outputs?is_sequence ]
                    [#list stack.Outputs as output ]
                        [#local pointSet += {
                            output.OutputKey : output.OutputValue
                        }]
                    [/#list]
                [/#if]

                [#if stack.Outputs?is_hash ]
                    [#local pointSet = stack.Outputs ]
                [/#if]

                [#if pointSet?has_content ]
                    [@debug
                        message="Normalise stack file " + stackFile.FileName!""
                        enabled=false
                    /]
                    [#local pointSets +=
                        [
                            validatePointSet(
                                mergeObjects(
                                    { "Level" : (stackFile.FileName!"")?split('-')[0]},
                                    pointSet
                                )
                             )
                        ]
                    ]
                [/#if]
            [/#list]
        [/#list]

        [#if stackFiles?has_content]
            [#return
                removeConfigPipelineClassCacheForStage(
                    combineEntities(
                        state,
                        {
                            STATE_CONFIG_INPUT_CLASS : pointSets
                        },
                        APPEND_COMBINE_BEHAVIOUR
                    ),
                    STATE_CONFIG_INPUT_CLASS,
                    CMDB_SHARED_INPUT_STAGE
                )
            ]
        [/#if]
    [/#if]
    [#return state]
[/#function]
