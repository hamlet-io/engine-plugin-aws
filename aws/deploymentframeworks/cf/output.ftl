[#ftl]

[#-- Availability Zone Params --]
[#-- Uses parameters to define AZ's inline with cfnlint best practice --]
[#assign AWS_AZ_PARAMETER_TYPE = "AvailabilityZoneParam"]

[#macro addCFTemplateAzParams zoneIds ]
    [#list asArray(zoneIds) as zoneId ]
        [#list getZones() as zone ]
            [#if zoneId == zone.Id ]
                [@cfParameter
                    id=formatAWSAzParameterId(zoneId)
                    type="AWS::EC2::AvailabilityZone::Name"
                    default=zone.AWSZone
                /]
            [/#if]
        [/#list]
    [/#list]
[/#macro]

[#function formatAWSAzParameterId zoneId ]
    [#return formatResourceId(AWS_AZ_PARAMETER_TYPE, zoneId)]
[/#function]

[#function getCFAWSAzReference zoneId ]
    [@addCFTemplateAzParams zoneIds=[zoneId] /]
    [#return { "Ref" : formatAWSAzParameterId(zoneId) }]
[/#function]

[#function getCFAWSAzReferences zoneIds]
    [#local result = []]
    [#list zoneIds as zoneId]
        [#local result += [ getCFAWSAzReference(zoneId) ]]
    [/#list]
    [#return result]
[/#function]

[#-- Template outputs --]
[#function getCFTemplateCoreOutputs region={ "Ref" : "AWS::Region" } account={ "Ref" : "AWS::AccountId" } deploymentUnit=getCLODeploymentUnit() deploymentMode=getCLODeploymentMode() ]
    [#return {
        "Account" :{ "Value" : account },
        "Region" : {"Value" : region },
        "DeploymentUnit" : {
            "Value" :
                deploymentUnit +
                (
                    (!(ignoreDeploymentUnitSubsetInOutputs!false)) &&
                    (getCLODeploymentUnitSubset()?has_content)
                )?then(
                    "-" + getCLODeploymentUnitSubset()?lower_case,
                    ""
                )
        },
        "DeploymentMode" : { "Value" : deploymentMode }
    }]
[/#function]

[#function getCfTemplateDefaultOutputs]
    [#return
        {
            REFERENCE_ATTRIBUTE_TYPE : {
                "UseRef" : true
            }
        }
    ]
[/#function]

[#function getCFResourceTags tags={} flatten=false maxTagCount=50]

    [#if ! tags?has_content]
        [#return flatten?then({}, [])]
    [/#if]

    [#local maxTagCount = ( maxTagCount -1 lt tags?keys?size )?then(
                                maxTagCount,
                                tags?keys?size
    )]

    [#if flatten ]

        [#local tags=tags?keys[0..( maxTagCount -1 )]?map(x -> { x: tags[x]})]

        [#local result = {}]
        [#list tags as tag]
            [#local result = mergeObjects(result, tag)]
        [/#list]

    [#else]
        [#local result = tags?keys?map(
            x -> {"Key": x, "Value": tags[x] }
        )]

        [#local result = result[0..( maxTagCount -1 )]]
    [/#if]
    [#return result]
[/#function]

[#-- Template Components --]
[#macro cfOutput id value export=false ]
    [@mergeWithJsonOutput
        name="outputs"
        content=
            {
                id : {
                    "Value" : value
                } +
                export?then(
                    {
                        "Export" : {
                            "Name" : {
                                "Fn::Join" :
                                    [ ":", [ { "Ref" : "AWS::StackName" }, id ] ]
                            }
                        }
                    },
                    {}
                )
            }
    /]
[/#macro]

[#macro cfResource
            id
            type
            properties={}
            tags={}
            outputs=getCfTemplateDefaultOutputs()
            outputId=""
            dependencies=[]
            metadata={}
            deletionPolicy=""
            updateReplacePolicy=""
            updatePolicy={}
            creationPolicy={}
    ]

    [#local localDependencies = [] ]
    [#list asArray(dependencies) as resourceId]
        [#if getReference(resourceId)?is_hash]
            [#local localDependencies += [resourceId] ]
        [/#if]
    [/#list]

    [@mergeWithJsonOutput
        name="resources"
        content=
            {
                id :
                    {
                        "Type" : type
                    } +
                    attributeIfContent("Metadata", metadata) +
                    attributeIfTrue(
                        "Properties",
                        properties?has_content || tags?has_content,
                        properties +
                        attributeIfContent(
                            "Tags",
                            tags,
                            tags?is_sequence?then(tags, getCFResourceTags(tags))
                        )
                    ) +
                    attributeIfContent("DependsOn", localDependencies) +
                    attributeIfContent("DeletionPolicy", deletionPolicy) +
                    attributeIfContent("UpdateReplacePolicy", updateReplacePolicy) +
                    attributeIfContent("UpdatePolicy", updatePolicy) +
                    attributeIfContent("CreationPolicy", creationPolicy)
            }
    /]

    [#assign oId = outputId?has_content?then(outputId, id)]
    [#list outputs as type,value]
        [#if type == REFERENCE_ATTRIBUTE_TYPE]
            [@cfOutput
                oId,
                {
                    "Ref" : id
                },
                value.Export!false
            /]
        [#else]

            [#if value.Replace?has_content ]
                [#local content = getJSON(value.Replace)]
                [#list [ "_id_" ] as replaceString ]
                    [#switch replaceString ]
                        [#case "_id_" ]
                            [#local content = content?replace(replaceString, id )]
                            [#break]
                    [/#switch]
                [/#list]

                [@cfOutput
                    formatAttributeId(oId, type),
                    content?eval_json,
                    value.Export!false
                /]
            [#else]
                [@cfOutput
                    formatAttributeId(oId, type),
                    ((value.UseRef)!false)?then(
                        {
                            "Ref" : id
                        },
                        value.Value?has_content?then(
                            value.Value,
                            {
                                "Fn::GetAtt" : [id, value.Attribute]
                            }
                        )
                    ),
                    value.Export!false
                /]
            [/#if]


        [/#if]
    [/#list]
[/#macro]

[#macro cfParameter
            id
            type
            default=""
            description=""
            allowedPattern=""
            allowedValues=""
            constraintDescription=""
            maxLength=""
            maxValue=""
            minLength=""
            minValue=""
            noEcho=false
    ]

    [@mergeWithJsonOutput
        name="parameters"
        content=
            {
                id : {
                    "Type" : type
                } +
                attributeIfContent(
                    "AllowedPattern",
                    allowedPattern
                ) +
                attributeIfContent(
                    "AllowedValues",
                    allowedValues
                ) +
                attributeIfContent(
                    "ConstraintDescription",
                    constraintDescription
                ) +
                attributeIfContent(
                    "Default",
                    default
                ) +
                attributeIfContent(
                    "Description",
                    description
                ) +
                attributeIfContent(
                    "MaxLength",
                    maxLength
                ) +
                attributeIfContent(
                    "MaxValue",
                    maxValue
                ) +
                attributeIfContent(
                    "MinLength",
                    minLength
                ) +
                attributeIfContent(
                    "MinValue",
                    minValue
                ) +
                attributeIfTrue(
                    "NoEcho",
                    noEcho,
                    "true"
                )
            }
    /]
[/#macro]


[#function cf_output_resource level="" include=""]

    [@setOutputProperties
        properties={ "type:file" : { "format" : "json" }}
    /]

    [#-- Resources --]
    [#if include?has_content]
        [#if include?contains("[#ftl]") ]
            [#-- treat as interpretable content --]
            [#local inlineInclude = include?interpret]
            [@inlineInclude /]
        [#else]
            [#-- assume a filename --]
            [#include include?ensure_starts_with("/") ]
        [/#if]
    [#else]
        [@processFlows
            level=level
            framework=CLOUD_FORMATION_DEPLOYMENT_FRAMEWORK
            flows=getCLOFlows()
        /]
    [/#if]

    [#if getOutputContent("resources")?has_content ]
        [#return
            {
                "AWSTemplateFormatVersion" : "2010-09-09",
                "Metadata" :
                    {
                        "Prepared" : .now?iso_utc,
                        "RequestReference" : getCLORequestReference(),
                        "ConfigurationReference" : getCLOConfigurationReference(),
                        "RunId" : getCLORunId()
                    } +
                    attributeIfContent("CostCentre", accountObject.CostCentre!""),
                "Resources" : getOutputContent("resources"),
                "Outputs" :
                    getOutputContent("outputs") +
                    getCFTemplateCoreOutputs()
            } +
            attributeIfContent(
                "Parameters",
                getOutputContent("parameters")
            )
        ]
    [/#if]
    [#return {}]
[/#function]

[#-- Initialise the possible outputs to make sure they are available to all steps --]
[@initialiseJsonOutput name="parameters" /]
[@initialiseJsonOutput name="resources" /]
[@initialiseJsonOutput name="outputs" /]

[#assign AWS_OUTPUT_RESOURCE_TYPE = "resource" ]

[#-- Add Output Step mappings for each output --]

[@addGenerationContractStepOutputMapping
    provider=AWS_PROVIDER
    subset="template"
    outputType=AWS_OUTPUT_RESOURCE_TYPE
    outputFormat=""
    outputSuffix="template.json"
/]


[#-- Deployment Contract --]
[#function getCFNStackName ]
    [#local stack_details = {
        "product": (getActiveLayer(PRODUCT_LAYER_TYPE).Name)!"",
        "environment": (getActiveLayer(ENVIRONMENT_LAYER_TYPE).Name)!"",
        "segment": (getActiveLayer(SEGMENT_LAYER_TYPE).Name)!"",
        "level": getDeploymentLevel(),
        "deployment_unit": getCLODeploymentUnit(),
        "district_type": getCommandLineOptions()["Input"]["Filter"]["DistrictType"]
    }]

    [#local stack_keys = ["product", "environment", "segment", "level", "deployment_unit"]]

    [#if stack_details["district_type"] == "account" ]
        [#local stack_keys = ["district_type", "deployment_unit"]]
    [/#if]

    [#local stack_name = []]
    [#list stack_keys as stack_key ]
        [#if (stack_details[stack_key]!"")?has_content ]

            [#switch stack_key ]
                [#case "level" ]
                    [#switch stack_details[stack_key]]
                        [#case "account"]
                            [#local stack_name += ["acct"]]
                            [#break]
                        [#case "application" ]
                            [#local stack_name += ["app"]]
                            [#break]
                        [#case "solution" ]
                            [#local stack_name += ["soln"]]
                            [#break]
                        [#case "segment"]
                            [#local stack_name += ["seg"]]
                            [#break]
                        [#break]
                            [#local stack_name += [ stack_details[stack_key] ]]
                    [/#switch]
                    [#break]


                [#case "segment" ]
                    [#if stack_details[stack_key] != "default" && stack_details["environment"] != stack_details["segment"] ]
                        [#local stack_name += [ stack_details[stack_key] ]]
                    [/#if]
                    [#break]

                [#default]
                    [#local stack_name += [ stack_details[stack_key] ]]
            [/#switch]
        [/#if]
    [/#list]

    [#return stack_name?join("-")]
[/#function]

[#macro addDefaultAWSDeploymentContract prologue=false stack=true changeset=false epilogue=false ]

    [#local stackName = getCFNStackName()]
    [#local changeSetName = "hamlet" + getCLORunId() ]
    [#local runId = getCLORunId()]

    [#local cfDir = (getCommandLineOptions().Output.cfDir)!""]
    [#local s3StackPath = "cfn/" + stackName + "/template.json"]

    [#local segmentOperationsDir = (getCommandLineOptions().Output.segmentOperationsDir)!""]

    [#local deploymentMode = getDeploymentMode()]
    [#local deploymentModeDetails = getDeploymentModeDetails(deploymentMode)]
    [#local deploymentModeOperations = deploymentModeDetails.Operations]

    [#local scriptEnv = {
        "STACK_NAME": stackName,
        "CF_DIR": cfDir,
        "SEGMENT_OPERATIONS_DIR": segmentOperationsDir
    }]

    [#list getActiveLayers() as type, layerInfo ]
        [#local scriptEnv = mergeObjects(scriptEnv, { type?upper_case: layerInfo.Name  })]
    [/#list]

    [#-- Update deployment contract name --]
    [#local contractRenameStageId = "contract_rename" ]
    [@contractStage
        id=contractRenameStageId
        executionMode=CONTRACT_EXECUTION_MODE_SERIAL
        priority=1
    /]
    [@contractStep
        id="rename_contract_file"
        stageId=contractRenameStageId
        taskType=RENAME_FILE_TASK_TYPE
        parameters={
            "currentFileName": formatAbsolutePath(
                cfDir,
                getOutputFileName("deploymentcontract", "", "")
            ),
            "newFileName": formatAbsolutePath(
                cfDir,
                getOutputFileName("deploymentcontract", "final", "")
            )
        }
    /]

    [#-- login to provider --]
    [#local loginStageId = "login" ]
    [@contractStage
        id=loginStageId
        executionMode=CONTRACT_EXECUTION_MODE_SERIAL
        priority=2
    /]

    [@contractStep
        id="aws_login"
        stageId=loginStageId
        taskType=SET_PROVIDER_CREDENTIALS_TASK_TYPE
        parameters={
            "AccountId" : getActiveLayer(ACCOUNT_LAYER_TYPE).Id,
            "Provider": AWS_PROVIDER,
            "ProviderId": getActiveLayer(ACCOUNT_LAYER_TYPE).ProviderId
        }
    /]

    [#list deploymentModeOperations as deploymentModeOperation ]

        [#local scriptEnv = mergeObjects(scriptEnv, { "STACK_OPERATION": deploymentModeOperation})]

        [#if prologue]
            [#-- prologue script --]
            [#local prologueStageId = "prologue"]
            [@contractStage
                id=prologueStageId
                executionMode=CONTRACT_EXECUTION_MODE_SERIAL
                priority=deploymentModeOperation?index * 100 + 10
            /]

            [@contractStep
                id="prologue_script_details"
                priority=10
                stageId=prologueStageId
                taskType=FILE_PATH_DETAILS_TASK_TYPE
                parameters={
                    "FilePath": formatAbsolutePath(
                        cfDir,
                        getOutputFileName("prologue", "", "")
                    )
                }
            /]

            [@contractStep
                id="no_prologue_file_skip"
                priority=15
                stageId=prologueStageId
                taskType=CONDITIONAL_STAGE_SKIP_TASK_TYPE
                status="skip_stage_if_failure"
                parameters={
                    "Test" : "True",
                    "Condition": "Equals",
                    "Value": "__Properties:output:prologue_script_details:exists__"
                }
            /]

            [@contractStep
                id="prologue_script"
                priority=20
                stageId=prologueStageId
                taskType=AWS_RUN_BASH_SCRIPT_TASK_TYPE
                parameters={
                    "ScriptPath": formatAbsolutePath(
                        cfDir,
                        getOutputFileName("prologue", "primary", "")
                    ),
                    "Environment": getJSON(scriptEnv),
                    "AWSAccessKeyId" : "__Properties:output:aws_login:aws_access_key_id__",
                    "AWSSecretAccessKey": "__Properties:output:aws_login:aws_secret_access_key__",
                    "AWSSessionToken" : "__Properties:output:aws_login:aws_session_token__"
                }
                status="available"
            /]
        [/#if]

        [#if ( stack || changeset ) && ["update", "create"]?seq_contains(deploymentModeOperation)  ]
            [#-- Templates to S3 --]
            [#local templateS3StageId = "templates_to_s3"]
            [@contractStage
                id=templateS3StageId
                executionMode=CONTRACT_EXECUTION_MODE_SERIAL
                priority=deploymentModeOperation?index * 100 + 20
            /]

            [@contractStep
                id="template_upload"
                stageId=templateS3StageId
                priority=100
                taskType=AWS_S3_UPLOAD_OBJECT_TASK_TYPE
                parameters={
                    "BucketName": getRegistryBucket(getRegion()),
                    "Object": s3StackPath,
                    "LocalPath": formatAbsolutePath(
                        cfDir,
                        getOutputFileName("template", "primary", "")
                    ),
                    "AWSAccessKeyId" : "__Properties:output:aws_login:aws_access_key_id__",
                    "AWSSecretAccessKey": "__Properties:output:aws_login:aws_secret_access_key__",
                    "AWSSessionToken" : "__Properties:output:aws_login:aws_session_token__"
                }
                status="available"
            /]

            [@contractStep
                id="template_presign"
                stageId=templateS3StageId
                priority=200
                taskType=AWS_S3_PRESIGN_URL_TASK_TYPE
                parameters={
                    "BucketName": getRegistryBucket(getRegion()),
                    "Object": s3StackPath,
                    "AWSAccessKeyId" : "__Properties:output:aws_login:aws_access_key_id__",
                    "AWSSecretAccessKey": "__Properties:output:aws_login:aws_secret_access_key__",
                    "AWSSessionToken" : "__Properties:output:aws_login:aws_session_token__"
                }
            /]
        [/#if]

        [#if stack && ["update", "create"]?seq_contains(deploymentModeOperation)  ]
            [#-- stack_execution --]
            [#local stackExecutionStageId = "stack_execution" ]
            [@contractStage
                id=stackExecutionStageId
                executionMode=CONTRACT_EXECUTION_MODE_SERIAL
                priority=deploymentModeOperation?index * 100 + 30
            /]

            [@contractStep
                id="run_stack"
                priority=10
                stageId=stackExecutionStageId
                taskType=AWS_CFN_RUN_STACK_TASK_TYPE
                parameters={
                    "RunId": runId,
                    "StackName": stackName,
                    "TemplateS3Uri": "__Properties:output:template_presign:presigned_url__",
                    "AWSAccessKeyId" : "__Properties:output:aws_login:aws_access_key_id__",
                    "AWSSecretAccessKey": "__Properties:output:aws_login:aws_secret_access_key__",
                    "AWSSessionToken" : "__Properties:output:aws_login:aws_session_token__"
                }
                status="available"
            /]
        [/#if]

        [#if changeset && ["update", "create"]?seq_contains(deploymentModeOperation)  ]
            [#-- Run through the change set process as required --]
            [#local changeSetExecutionStageId = "change_set_execution" ]
            [@contractStage
                id=changeSetExecutionStageId
                executionMode=CONTRACT_EXECUTION_MODE_SERIAL
                priority=deploymentModeOperation?index * 100 + 40
            /]

            [@contractStep
                id="create_change_set"
                priority=10
                stageId=changeSetExecutionStageId
                taskType=AWS_CFN_CREATE_CHANGE_SET_TASK_TYPE
                parameters={
                    "RunId": runId,
                    "ChangeSetName": changeSetName,
                    "StackName": stackName,
                    "TemplateS3Uri": "__Properties:output:template_presign:presigned_url__",
                    "AWSAccessKeyId" : "__Properties:output:aws_login:aws_access_key_id__",
                    "AWSSecretAccessKey": "__Properties:output:aws_login:aws_secret_access_key__",
                    "AWSSessionToken" : "__Properties:output:aws_login:aws_session_token__"
                }
                status="available"
            /]

            [@contractStep
                id="no_changes_skip"
                priority=15
                stageId=changeSetExecutionStageId
                taskType=CONDITIONAL_STAGE_SKIP_TASK_TYPE
                status="skip_stage_if_failure"
                parameters={
                    "Test" : "True",
                    "Condition": "Equals",
                    "Value": "__Properties:output:create_change_set:changes_required__"
                }
            /]

            [@contractStep
                id="change_set_results"
                stageId=changeSetExecutionStageId
                taskType=AWS_CFN_GET_CHANGE_SET_CHANGES_TASK_TYPE
                parameters={
                    "ChangeSetName": changeSetName,
                    "StackName": stackName,
                    "AWSAccessKeyId" : "__Properties:output:aws_login:aws_access_key_id__",
                    "AWSSecretAccessKey": "__Properties:output:aws_login:aws_secret_access_key__",
                    "AWSSessionToken" : "__Properties:output:aws_login:aws_session_token__"
                }
                status="available"
            /]

            [@contractStep
                id="exceute_change_set"
                stageId=changeSetExecutionStageId
                taskType=AWS_CFN_EXECUTE_CHANGE_SET_TASK_TYPE
                parameters={
                    "RunId": runId,
                    "ChangeSetName": changeSetName,
                    "StackName": stackName,
                    "AWSAccessKeyId" : "__Properties:output:aws_login:aws_access_key_id__",
                    "AWSSecretAccessKey": "__Properties:output:aws_login:aws_secret_access_key__",
                    "AWSSessionToken" : "__Properties:output:aws_login:aws_session_token__"
                }
                status="available"
            /]
        [/#if]

        [#if ( stack || changeset ) && ["update", "create"]?seq_contains(deploymentModeOperation)  ]
            [#-- Get Outputs from stack --]
            [#local outputStackStageId = "outputs"]
            [@contractStage
                id=outputStackStageId
                executionMode=CONTRACT_EXECUTION_MODE_SERIAL
                priority=deploymentModeOperation?index * 100 + 50
            /]

            [@contractStep
                id="outputs"
                stageId=outputStackStageId
                taskType=AWS_CFN_WRITE_STACK_OUTPUTS_TO_FILE_TASK_TYPE
                parameters={
                    "StackName": stackName,
                    "AWSAccessKeyId" : "__Properties:output:aws_login:aws_access_key_id__",
                    "AWSSecretAccessKey": "__Properties:output:aws_login:aws_secret_access_key__",
                    "AWSSessionToken" : "__Properties:output:aws_login:aws_session_token__",
                    "FilePath": formatAbsolutePath(
                        cfDir,
                        getOutputFileName("stack", "", "")
                    )
                }
                status="available"
            /]
        [/#if]

        [#if ( stack || changeset ) && ["delete" ]?seq_contains(deploymentModeOperation)  ]

            [#-- Delete the stack --]
            [#local deleteStackStageId = "delete_stack"]
            [@contractStage
                id=deleteStackStageId
                executionMode=CONTRACT_EXECUTION_MODE_SERIAL
                priority=deploymentModeOperation?index * 100 + 50
            /]

            [@contractStep
                id="delete_stack"
                stageId=deleteStackStageId
                taskType=AWS_CFN_DELETE_STACK_TASK_TYPE
                parameters={
                    "StackName": stackName,
                    "RunId": runId,
                    "AWSAccessKeyId" : "__Properties:output:aws_login:aws_access_key_id__",
                    "AWSSecretAccessKey": "__Properties:output:aws_login:aws_secret_access_key__",
                    "AWSSessionToken" : "__Properties:output:aws_login:aws_session_token__"
                }
                status="available"
            /]

            [@contractStep
                id="delete_stack_output"
                stageId=deleteStackStageId
                taskType=FILE_DELETE_TASK_TYPE
                parameters={
                    "FilePath": formatAbsolutePath(
                        cfDir,
                        getOutputFileName("stack", "primary", "")
                    )
                }
            /]
        [/#if]

        [#if epilogue]
            [#-- epilogue script --]
            [#local epilogueStageId = "epilogue"]
            [@contractStage
                id=epilogueStageId
                executionMode=CONTRACT_EXECUTION_MODE_SERIAL
                priority=deploymentModeOperation?index * 100 + 60
            /]

            [@contractStep
                id="epilogue_script_details"
                priority=10
                stageId=epilogueStageId
                taskType=FILE_PATH_DETAILS_TASK_TYPE
                parameters={
                    "FilePath": formatAbsolutePath(
                        cfDir,
                        getOutputFileName("epilogue", "", "")
                    )
                }
            /]

            [@contractStep
                id="no_epilogue_file_skip"
                priority=15
                stageId=epilogueStageId
                taskType=CONDITIONAL_STAGE_SKIP_TASK_TYPE
                status="skip_stage_if_failure"
                parameters={
                    "Test" : "True",
                    "Condition": "Equals",
                    "Value": "__Properties:output:epilogue_script_details:exists__"
                }
            /]

            [@contractStep
                id="epilogue_script"
                priority=20
                stageId=epilogueStageId
                taskType=AWS_RUN_BASH_SCRIPT_TASK_TYPE
                parameters={
                    "ScriptPath": formatAbsolutePath(
                        cfDir,
                        getOutputFileName("epilogue", "primary", "")
                    ),
                    "Environment": getJSON(scriptEnv),
                    "AWSAccessKeyId" : "__Properties:output:aws_login:aws_access_key_id__",
                    "AWSSecretAccessKey": "__Properties:output:aws_login:aws_secret_access_key__",
                    "AWSSessionToken" : "__Properties:output:aws_login:aws_session_token__"
                }
                status="available"
            /]
        [/#if]
    [/#list]
[/#macro]
