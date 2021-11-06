[#ftl]

[@registerInputSeeder
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
            addToConfigPipelineStageCacheForClass(
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

    [#-- Resource specific values to align with linting --]
    [@includeServicesConfiguration
        provider=AWS_PROVIDER
        services=[
            AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE,
            AWS_NETWORK_FIREWALL_SERVICE,
            AWS_IDENTITY_SERVICE
            AWS_SIMPLE_STORAGE_SERVICE
        ]
        deploymentFramework=CLOUD_FORMATION_DEPLOYMENT_FRAMEWORK
    /]

    [#switch id?split("X")?first ]
        [#case AWS_IAM_MANAGED_POLICY_RESOURCE_TYPE]
            [#if id?ends_with(ARN_ATTRIBUTE_TYPE)]
                [#local value = "arn:aws:iam::123456789012:policy/managedPolicyXuserXappXapiuserbaseXlinksXarn"]
            [/#if]
            [#break]

        [#case AWS_IAM_ROLE_RESOURCE_TYPE]
            [#if id?ends_with(ARN_ATTRIBUTE_TYPE)]
                [#local value = "arn:aws:iam::123456789012:role/managedPolicyXuserXappXapiuserbaseXlinksXarn"]
            [/#if]
            [#break]

        [#case AWS_NETWORK_FIREWALL_RESOURCE_TYPE]
            [#if id?ends_with(INTERFACE_ATTRIBUTE_TYPE)]
                [#local value = "ap-mock-1a:vpce-111122223333,ap-mock-1b:vpce-987654321098,ap-mock-1c:vpce-012345678901"]
            [/#if]
            [#break]

        [#case AWS_S3_RESOURCE_TYPE]
            [#if id?ends_with(NAME_ATTRIBUTE_TYPE)]
                [#local value = replaceAlphaNumericOnly(id)?lower_case]
            [/#if]
            [#break]

        [#case AWS_VPC_RESOURCE_TYPE ]
            [#-- this will return the value for all attribute lookups --]
            [#-- VPC only has ref so that is ok --]
            [#local value = "vpc-123456789abcdef12" ]
            [#break]
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
    [#-- Override any value already mocked by the shared seeder --]
    [#if (!state.Value?has_content) || (state.Mocked!false)]
        [#return aws_stateseeder_fixture(filter, state) ]
    [/#if]
    [#return state]
[/#function]
