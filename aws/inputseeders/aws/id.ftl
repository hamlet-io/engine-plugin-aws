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

[@addSeederToStatePipeline
    stage=FIXTURE_SHARED_INPUT_STAGE
    seeder=AWS_INPUT_SEEDER
/]

[@addSeederToStatePipeline
    stage=SIMULATE_SHARED_INPUT_STAGE
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

[#function aws_configseeder_masterdata filter state]
    [#if filterAttributeContainsValue(filter, "Provider", AWS_PROVIDER) ]
        [#local requiredRegions =
            getMatchingFilterAttributeValues(
                filter,
                "Region",
                aws_cmdb_regions?keys
            )
        ]
        [#return
            addToConfigPipelineClass(
                state,
                BLUEPRINT_CONFIG_INPUT_CLASS,
                aws_cmdb_masterdata +
                {
                    "Regions" :
                        requiredRegions?has_content?then(
                            getObjectAttributes(aws_cmdb_regions, requiredRegions),
                            aws_cmdb_regions
                        )
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

[#-- Normalise cloud formation stack files to state point sets --]
[#function aws_configtransformer_normalise filter state]

    [#if filterAttributeContainsValue(filter, "Provider", AWS_PROVIDER) ]

        [#-- Anything to process? --]
        [#local stackFiles =
            (getConfigPipelineClassCacheForStages(
                state,
                STATE_CONFIG_INPUT_CLASS,
                [
                    FIXTURE_SHARED_INPUT_STAGE,
                    MODULE_SHARED_INPUT_STAGE,
                    CMDB_SHARED_INPUT_STAGE
                ]
            )[STATE_CONFIG_INPUT_CLASS])![]
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
                addToConfigPipelineClass(
                    state,
                    STATE_CONFIG_INPUT_CLASS,
                    pointSets
                )
            ]
        [/#if]
    [/#if]
    [#return state]
[/#function]

[#-- AWS Mock Output --]
[#function aws_stateseeder_fixture filter state ]

    [#local id = state.Id]

    [#switch id?split("X")?last ]
        [#case ARN_ATTRIBUTE_TYPE ]
            [#local value = "arn:aws:iam::123456789012:mock/" + id ]
            [#break]
        [#case URL_ATTRIBUTE_TYPE ]
            [#local value = "https://mock.local/" + id ]
            [#break]
        [#case IP_ADDRESS_ATTRIBUTE_TYPE ]
            [#local value = "123.123.123.123" ]
            [#break]
        [#case REGION_ATTRIBUTE_TYPE ]
            [#local value = "ap-mock-1" ]
            [#break]
        [#default]
            [#local value = formatId( "##MockOutput", id, "##") ]
    [/#switch]

    [#return
        mergeObjects(
            state,
            {
                "Value" : value
            }
        )
    ]

[/#function]

[#function aws_stateseeder_simulate filter state]
    [#if ! state.Value?has_content]
        [#return aws_stateseeder_fixture(filter, state) ]
    [/#if]
    [#return state]
[/#function]
