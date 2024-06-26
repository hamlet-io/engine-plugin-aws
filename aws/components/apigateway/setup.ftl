[#ftl]

[#macro aws_apigateway_cf_deployment_generationcontract_application occurrence ]
    [@addDefaultGenerationContract subsets=["deploymentcontract", "pregeneration", "prologue", "template", "epilogue", "config", "cli" ] /]
[/#macro]

[#macro aws_apigateway_cf_deployment_deploymentcontract occurrence ]
    [@addDefaultAWSDeploymentContract prologue=true epilogue=true /]
[/#macro]

[#macro aws_apigateway_cf_deployment_application occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]
    [#local attributes = occurrence.State.Attributes ]
    [#local image =  getOccurrenceImage(occurrence)]
    [#local buildReference =
        contentIfContent(
            image.Tag!"",
            contentIfContent(
                image.Reference!"",
                "HamletFatal No build reference defined"
            )
        ) ]
    [#local buildRegistry = image.Format!"HamletFatal No build format defined" ]
    [#local roles = occurrence.State.Roles]

    [#local definitionsObject =  getDefinitions() ]

    [#local openapiIntegrations =
        contentIfContent(
            getOccurrenceSettingValue(occurrence, [["apigw"], ["Integrations"]], true)
        )
    ]

    [#local apiId      = resources["apigateway"].Id]
    [#local apiName    = resources["apigateway"].Name]

    [#-- Execution Log Group --]
    [#local executionLgId   = resources["lg"].Id]
    [#local executionLgName = resources["lg"].Name]

    [#-- Access Log Group --]
    [#local accessLgId   = resources["accesslg"].Id]
    [#local accessLgName = resources["accesslg"].Name]

    [#-- Use runId to ensure deploy happens every time --]
    [#local deployId   = resources["apideploy"].Id]
    [#local deployName = resources["apideploy"].Name]
    [#local stageId    = resources["apistage"].Id]
    [#local stageName  = resources["apistage"].Name]
    [#local stageLogTarget = accessLgId]

    [#-- Determine the stage variables required --]
    [#local stageVariables = {} ]

    [#local openapiFileName ="openapi_" + getCLORunId() + ".json"  ]
    [#local openapiFileLocation = formatRelativePath(
                                                getSettingsFilePrefix(occurrence),
                                                "config",
                                                openapiFileName)]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, ["Encryption", "OpsData", "AppData" ] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local operationsBucket = getExistingReference(baselineComponentIds["OpsData"]) ]
    [#local kmsKeyId = baselineComponentIds["Encryption"]]

    [#local contextLinks = getLinkTargets(occurrence) ]
    [#local _context =
        {
            "DefaultEnvironment" : defaultEnvironment(occurrence, contextLinks, baselineLinks),
            "Environment" : {},
            "Links" : contextLinks,
            "BaselineLinks" : baselineLinks,
            "DefaultCoreVariables" : false,
            "DefaultBaselineVariables" : false,
            "DefaultEnvironmentVariables" : false,
            "DefaultLinkVariables" : false,
            "Policy" : [],
            "OpenAPIDefinition" : internalEnsureAWSDefinitionCompatability((definitionsObject[core.Id])!{})
        }
    ]
    [#-- Add in extension specifics including override of defaults --]
    [#local _context = invokeExtensions( occurrence, _context )]

    [#local stageVariables += getFinalEnvironment(occurrence, _context ).Environment ]
    [#local openapiDefinition = _context.OpenAPIDefinition ]

    [#local cognitoPools = {} ]
    [#local lambdaAuthorizers = {} ]
    [#local privateHTTPEndpoints = {} ]
    [#local sourceVPCEndpoints = [] ]

    [#list solution.Links?values as link]
        [#if link?is_hash]
            [#local linkTarget = getLinkTarget(occurrence, link, false) ]

            [@debug message="Link Target" context=linkTarget enabled=false /]

            [#if !linkTarget?has_content]
                [#continue]
            [/#if]

            [#local linkTargetCore = linkTarget.Core ]
            [#local linkTargetConfiguration = linkTarget.Configuration ]
            [#local linkTargetResources = linkTarget.State.Resources ]
            [#local linkTargetAttributes = linkTarget.State.Attributes ]
            [#local linkTargetSolution = linkTargetConfiguration.Solution]

            [#switch linkTargetCore.Type]
                [#case LB_COMPONENT_TYPE ]
                    [#if isLinkTargetActive(linkTarget) ]
                        [#local stageVariables +=
                            {
                                formatSettingName(true, link.Name, "DOCKER") : linkTargetAttributes.FQDN
                            }
                        ]
                    [/#if]
                    [#break]

                [#case LB_PORT_COMPONENT_TYPE]

                    [#local portUrlStageVariable = formatSettingName(true, link.Name, "HTTP", "URL" ) ]
                    [#local stageVariables +=
                        {
                            portUrlStageVariable : linkTargetAttributes.URL
                        }
                    ]

                    [#if ((linkTargetResources["apiGatewayLink"])!{})?has_content ]
                        [#local privateHTTPEndpoints += {
                            link.Name : {
                                "StageVariable" : portUrlStageVariable,
                                "connectionId" : getExistingReference( linkTargetResources["apiGatewayLink"].Id ),
                                "uri" : linkTargetAttributes.URL
                            }
                        }]
                    [/#if]
                    [#break]

                [#case LAMBDA_FUNCTION_COMPONENT_TYPE]
                    [#-- Add function even if it isn't active so API gateway is fully configured --]
                    [#-- even if lambda have yet to be deployed                                  --]
                    [#local stageVariableName =
                            formatSettingName(
                                true,
                                link.Name,
                                linkTargetCore.SubComponent.Name,
                                "LAMBDA")
                    ]
                    [#-- The stage variable is used in the openapi extensions as part of the ARN     --]
                    [#-- of the backing function. While ideally the entire ARN would be substituted, --]
                    [#-- that is not currently supported by the AWS integration extension.           --]
                    [#--                                                                             --]
                    [#-- NOTE: if the lambda is versioned, the result will include the lambda        --]
                    [#-- version. It also means that the lambda deployments will need to precede     --]
                    [#-- the api deployment, which is problematic initially in that the lambdas need --]
                    [#-- the API to exist to permit it to invoke them. The options are either to run --]
                    [#-- the API deployment both before AND after the lambdas, or run it after and   --]
                    [#-- accept the API will not work as expected when initially deployed until      --]
                    [#-- the lambda functions are deployed a second time and their resource polciies --]
                    [#-- updated to include the API.                                                 --]
                    [#--                                                                             --]
                    [#-- NOTE: this code will also handle lambda alias ARNs, which include the alias --]
                    [#-- in the same location as the version. Use of an alias would mitigate the     --]
                    [#-- issues described above as the openapi config would be using a fixed arn     --]
                    [#-- which does not vary as the lambda function version changes.                 --]
                    [#local stageVariables +=
                        {
                            stageVariableName :
                                linkTargetAttributes.ARN?keep_after("function:")
                        }
                    ]
                    [#if ["authorise", "authorize"]?seq_contains(linkTarget.Role) ]
                        [#local lambdaAuthorizers +=
                            {
                                link.Name : {
                                    "Name" : link.Name,
                                    "StageVariable" : stageVariableName,
                                    "Default" : true,
                                    "SettingsPrefix" : getOccurrenceSettingValue(linkTarget, "SETTINGS_PREFIX")
                                }
                            } ]
                    [/#if]
                    [#break]

                [#case USERPOOL_COMPONENT_TYPE]
                    [#if isLinkTargetActive(linkTarget) ]
                        [#local cognitoPools +=
                            {
                                link.Name : {
                                    "Name" : link.Name,
                                    "Header" : linkTargetAttributes["API_AUTHORIZATION_HEADER"],
                                    "UserPoolArn" : linkTargetAttributes["USER_POOL_ARN"],
                                    "Default" : true
                                }
                            } ]
                    [/#if]
                    [#break]

                [#case EXTERNALSERVICE_COMPONENT_TYPE]
                    [#-- For private APIs, provide the consumer vpc endpoints via an external service  --]
                    [#-- If wanting public access, define an external service with a VPCEndpoint value --]
                    [#-- of "_global" or its variants                                                  --]
                    [#if linkTarget.Direction == "inbound" ]
                        [#local vpcEndpoints = linkTargetAttributes["VPC_ENDPOINTS"]!"" ]
                        [#if vpcEndpoints?has_content]
                            [#local sourceVPCEndpoints += vpcEndpoints?split(",") ]
                        [/#if]
                    [/#if]
                    [#break]
            [/#switch]
        [/#if]
    [/#list]

    [#local endpointType           = solution.EndpointType ]
    [#local isPrivateEndpointType  = endpointType == "PRIVATE" ]
    [#local isRegionalEndpointType = endpointType == "REGIONAL" ]

    [#local securityProfile        = getSecurityProfile(occurrence, core.Type)]
    [#local loggingProfile         = getLoggingProfile(occurrence)]

    [#local wafAclResources          = resources["wafacl"]!{} ]
    [#local wafLogStreamingResources = resources["wafLogStreaming"]!{}]

    [#local accessLogStreamingResources = resources["accessLogStreaming"]!{} ]

    [#local cfResources            = resources["cf"]!{} ]
    [#local customDomainResources  = resources["customDomains"]!{} ]

    [#local apiPolicyStatements    = _context.Policy ]
    [#local apiPolicyAuth          = solution.AuthorisationModel?upper_case ]
    [#-- For backwards compatability, IP is treated the same as SOURCE --]
    [#if apiPolicyAuth == "IP"]
        [#local apiPolicyAuth = "SOURCE" ]
    [/#if]

    [#if isPrivateEndpointType ]
        [#local sourceConfigIsProvided = sourceVPCEndpoints?has_content ]
        [#local sourceVPCEndpoints     = sourceVPCEndpoints?filter(e -> !["_global", "_global_", "__global__"]?seq_contains(e)) ]
        [#local sourceConfigIsClosed   = sourceVPCEndpoints?has_content ]
    [#else]
        [#local sourceCidr             = getGroupCIDRs(solution.IPAddressGroups) ]
        [#local sourceConfigIsProvided = sourceCidr?has_content ]
        [#local sourceConfigIsClosed   = sourceConfigIsProvided && getGroupCIDRs(solution.IPAddressGroups, true, {}, true) ]
    [/#if]

    [#if (!(wafAclResources?has_content)) && (!sourceConfigIsProvided) ]
        [@fatal
            message="No IP Address Groups provided on or VPC endpoints linked to the API Gateway. At a minimum, provide \"_global\" for general access."
            context={
                "Id": occurrence.Core.RawId
            }
        /]
        [#return]
    [/#if]

    [#-- Determine the resource policy                                                --]
    [#--                                                                              --]
    [#-- The way policy evaluation works for various configuration options is now     --]
    [#-- documented at                                                                --]
    [#-- https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-authorization-flow.html --]
    [#--                                                                              --]
    [#-- For SIG4 variants, AWS_IAM must be enabled in the openAPI specification      --]
    [#-- If AWS_IAM is enabled, it's IAM policy is evaluated in the usual fashion     --]
    [#-- with the resource policy. However if NOT defined, there is no explicit ALLOW --]
    [#-- (at present) so the resource policy must provide one.                        --]
    [#-- If an "AWS_ALLOW" were introduced in the openAPI spec to provide the ALLOW,  --]
    [#-- then the switch below could be simplified.                                   --]
    [#--                                                                              --]
    [#-- NOTE: for the SIG4 and Authorizer OR variants, a valid IAM identity/token    --]
    [#-- must STILL be provided but it does not need to provide an explicit ALLOW on  --]
    [#-- the resource if an explicit ALLOW is provided via the IP Address.            --]
    [#--                                                                              --]
    [#-- NOTE: for Cognito Authorizer, the authorizer and IP must both provide an     --]
    [#-- explicit ALLOW so can effectively be configured separately. Thus the model   --]
    [#-- should be the "SOURCE" default.                                              --]
    [#--                                                                              --]
    [#-- NOTE: the format of the resource arn is non-standard, and differs slightly   --]
    [#-- from that documented at                                                      --]
    [#-- https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html#api-gateway-iam-policy-resource-format-for-executing-api --]
    [#-- It seems like a workaround to the fact that cloud formation                  --]
    [#-- reports a circular reference if the policy references the apiId via the arn. --]
    [#-- (see case 5398420851)                                                        --]
    [#--                                                                              --]

    [#-- Ensure the stage(s) used for deployments can't be accessed externally --]
    [#local apiPolicyStatements +=
        [
            getPolicyStatement(
                "execute-api:Invoke",
                "execute-api:/default/*",
                "*",
                {},
                false
            )
        ] ]
    [#if sourceConfigIsClosed ]
        [#-- If lambda authorizers are in use, and the default AuthorisationModel (SOURCE) is --]
        [#-- in effect, warn and force the model to a valid value                         --]
        [#if lambdaAuthorizers?has_content && !apiPolicyAuth?starts_with("AUTHORI") ]
            [@fatal
                message="Authorization model of \"" + apiPolicyAuth + "\" is not compatible with the use of lambda authorizers"
                detail="Use one of the AUTHORISER models"
            /]
            [#local apiPolicyAuth = "AUTHORISER_AND_SOURCE" ]
        [/#if]

        [#-- If cognito authorizers are in use, the AuthorisationModel must be SOURCE --]
        [#if cognitoPools?has_content && (apiPolicyAuth != "SOURCE") ]
            [@fatal
                message="Authorization model of \"" + apiPolicyAuth + "\" is not compatible with the use of cognito authorizers"
                detail="Use the SOURCE model"
            /]
            [#local apiPolicyAuth = "SOURCE" ]
        [/#if]

        [#-- Ensure the stage(s) used for deployments can't be accessed externally --]
        [#switch apiPolicyAuth ]
            [#case "SOURCE" ]
            [#case "IP" ]
                [#-- Resource policy MUST provide explicit ALLOW --]
                [#local apiPolicyStatements +=
                    [
                        [#-- Explicit ALLOW by default --]
                        getPolicyStatement(
                            "execute-api:Invoke",
                            "execute-api:/*",
                            "*"
                        ),
                        [#-- DENY if not the expected source --]
                        getPolicyStatement(
                            "execute-api:Invoke",
                            "execute-api:/*",
                            "*",
                            valueIfTrue(
                                getVPCEndpointCondition(sourceVPCEndpoints, false),
                                isPrivateEndpointType,
                                getIPCondition(sourceCidr, false)
                            ),
                            false
                        )
                    ]
                ]
                [#break]

            [#case "SIG4ORIP" ]
            [#case "AWS:SIG4_OR_IP" ]
            [#case "AUTHORIZER_OR_SOURCE" ]
            [#case "AUTHORIZER_OR_IP" ]
            [#case "AUTHORISER_OR_IP" ]
                [#-- Resource policy provides ALLOW on SOURCE --]
                [#-- AWS_IAM provides ALLOW on SIG4           --]
                [#-- If SOURCE doesn't match, IAM policy MUST --]
                [#-- provide explicit ALLOW                   --]
                [#local apiPolicyStatements +=
                    [
                        getPolicyStatement(
                            "execute-api:Invoke",
                            "execute-api:/*",
                            "*",
                            valueIfTrue(
                                getVPCEndpointCondition(sourceVPCEndpoints),
                                isPrivateEndpointType,
                                getIPCondition(sourceCidr)
                            )
                        )
                    ]
                ]

                [#-- OPTIONS need to be handled separately in case    --]
                [#-- options security is disabled in the integrations --]
                [#if (openapiIntegrations.Options!true) &&
                    ((openapiIntegrations.OptionsSecurity!"") == "disabled") ]
                    [#local apiPolicyStatements +=
                        [
                            getPolicyStatement(
                                "execute-api:Invoke",
                                "execute-api:/*/OPTIONS/*",
                                "*"
                            )
                        ]
                    ]
                [/#if]
                [#break]

            [#case "SIG4ANDIP" ]
            [#case "AWS:SIG4_AND_IP" ]
            [#case "AUTHORIZER_AND_SOURCE" ]
            [#case "AUTHORIZER_AND_IP" ]
            [#case "AUTHORISER_AND_IP" ]
                [#-- If SOURCE doesn't match, EXPLICIT DENY regardless   --]
                [#-- If SOURCE matches, then IAM policy MUST provide the --]
                [#-- explicit ALLOW.                                     --]
                [#local apiPolicyStatements +=
                    [
                        getPolicyStatement(
                            "execute-api:Invoke",
                            "execute-api:/*",
                            "*",
                            valueIfTrue(
                                getVPCEndpointCondition(sourceVPCEndpoints, false),
                                isPrivateEndpointType,
                                getIPCondition(sourceCidr, false)
                            ),
                            false
                        )
                    ]
                ]

                [#-- OPTIONS need to be handled separately in case    --]
                [#-- options security is disabled in the integrations --]
                [#if (openapiIntegrations.Options!true) &&
                    ((openapiIntegrations.OptionsSecurity!"") == "disabled") ]
                    [#local apiPolicyStatements +=
                        [
                            getPolicyStatement(
                                "execute-api:Invoke",
                                "execute-api:/*/OPTIONS/*",
                                "*"
                            )
                        ]
                    ]
                [/#if]
                [#break]

            [#default]
                [@fatal message="Internal error: Unknown authorization model" context=apiPolicyAuth /]
                [#break]
        [/#switch]
    [#else]
        [#-- No SOURCE filtering required                                        --]
        [#-- Because we must have a resource policy to block the default stage,  --]
        [#-- the policy also needs to provide an explicit ALLOW to satisfy the   --]
        [#-- "API Gateway authorization workflow" for other types of authorizers --]
        [#local apiPolicyStatements +=
            [
                getPolicyStatement(
                    "execute-api:Invoke",
                    "execute-api:/*",
                    "*"
                )
            ] ]
    [/#if]

    [#-- mutualTLS client certificates --]
    [#local mutualTLSConfig = solution.MutualTLS ]
    [#local mutualTLS = solution.MutualTLS.Enabled ]
    [#if mutualTLS && ! customDomainResources?has_content ]
        [@fatal
            message="Mutual TLS can only be enabled if a Certifcate/Custom domain has been configured"
            detail="Configure the Certificate section of the apigateway"
            context={
                "APIGWId" : core.RawName,
                "MututalTLSConfig" : solution.MutualTLS
            }
        /]
    [/#if]

    [#local mutualTLSRootCAFileName = ""]
    [#local mutualTLSTrustStore = ""]
    [#local mutualTLSTrustPrefix = formatRelativePath(
                getOccurrenceSettingValue(occurrence, "SETTINGS_PREFIX"),
                "mutualTLS"
            )]

    [#if mutualTLS ]

        [#switch mutualTLSConfig.CertificateAuthority.Source ]
            [#case "link"]

                [#local mutualTLSRootCAFileName = "rootCA.pem"]
                [#local certificateAuthorityLink = getLinkTarget(occurrence, mutualTLSConfig.CertificateAuthority["Source:link"].Link )]

                [#local certificateAuthorityLinkAttribute = mutualTLSConfig.CertificateAuthority["Source:link"]["RootCACertAttribute"] ]
                [#if certificateAuthorityLink?has_content ]
                    [#local certificateAuthorityRootPublicCert = (certificateAuthorityLink.State.Attributes[certificateAuthorityLinkAttribute])!"" ]

                    [#if ! (certificateAuthorityRootPublicCert?has_content) ]
                        [@fatal
                            message="RootCA link attribute could not be found or was empty"
                            context={
                                "APIGWId" : core.RawName,
                                "MututalTLSConfig" : mutualTLSConfig
                            }
                        /]
                    [/#if]

                    [#if certificateAuthorityRootPublicCert?has_content  ]

                        [#if deploymentSubsetRequired("prologue", false)]
                            [@addToDefaultBashScriptOutput
                                content=
                                    writeFileForSync(
                                        "rootCAFile",
                                        mutualTLSRootCAFileName,
                                        certificateAuthorityRootPublicCert
                                    ) +
                                    syncFilesToBucketScript(
                                        "rootCAFile",
                                        getRegion(),
                                        operationsBucket,
                                        mutualTLSTrustPrefix,
                                        false
                                    )
                            /]
                        [/#if]
                    [/#if]
                [/#if]
                [#break]

            [#case "filesetting"]
                [#local mutualTLSRootCAFileName = mutualTLSConfig.CertificateAuthority["Source:filesetting"].FileName ]
                [#local caFileAvailable = getAsFileSettings(occurrence.Configuration.Settings.Product)
                            ?filter( x -> x.Value == mutualTLSRootCAFileName)
                            ?has_content ]

                [#if ! caFileAvailable ]
                    [@fatal
                        message="Cound not find mutualTLS Root CA from filesetting"
                        detail={
                            "APIGWId" : core.RawName,
                            "MututalTLSConfig" : mutualTLSConfig,
                            "FileSettings" : getAsFileSettings(occurrence.Configuration.Settings.Product)
                        }
                    /]
                [/#if]

                [#if deploymentSubsetRequired("prologue", false)]
                        [#-- Copy any asFiles needed by the task --]
                        [#local asFiles = getAsFileSettings(occurrence.Configuration.Settings.Product) ]
                        [#if asFiles?has_content]
                            [@addToDefaultBashScriptOutput
                                content=
                                    findAsFilesScript("filesToSync", asFiles) +
                                    syncFilesToBucketScript(
                                        "filesToSync",
                                        getRegion(),
                                        operationsBucket,
                                        mutualTLSTrustPrefix
                                        false
                                    )
                                /]
                        [/#if]
                    [/#if]
                [#break]
        [/#switch]

        [#local mutualTLSTrustStore = formatRelativePath(
                                        "s3://",
                                        operationsBucket,
                                        mutualTLSTrustPrefix
                                        mutualTLSRootCAFileName
                                    )]
    [/#if]

    [#local accessLogging = solution.AccessLogging ]

    [#-- Determine the log format --]
    [#-- TODO(mfl): tweak format to better capture waf, authorizer, integration info --]
    [#switch accessLogging["aws:LogFormat"].Syntax ]
        [#case "json" ]
            [#local accessLogFormat =
                getJSON(
                    {
                        "requestId" : "$context.requestId",
                        "extendedRequestId" : "$context.extendedRequestId",
                        "ip" : "$context.identity.sourceIp",
                        "caller" : "$context.identity.caller",
                        "user" : "$context.identity.user",
                        "requestTime" : "$context.requestTime",
                        "httpMethod" : "$context.httpMethod",
                        "resourcePath" : "$context.resourcePath",
                        "status" : "$context.status",
                        "protocol" : "$context.protocol",
                        "responseLength" : "$context.responseLength"
                    }
                ) ]
            [#break]

        [#default]
            [#local accessLogFormat = [
                "$context.identity.sourceIp",
                "$context.identity.caller",
                "$context.identity.user",
                "$context.identity.userArn",
                "[$context.requestTime]",
                "$context.apiId $context.httpMethod",
                "$context.resourcePath",
                "$context.protocol",
                "$context.status",
                "$context.responseLength",
                "$context.requestId"]?join(" ") ]
            [#break]
    [/#switch]

    [#if accessLogging.Enabled]

        [#-- Manage Access Logs with Kinesis Firehose --]
        [#if accessLogging["aws:KinesisFirehose"] ]

            [#local stageLogTarget = accessLogStreamingResources["stream"].Id ]

            [#-- Default destination is the Ops Data bucket, unless another link is provided --]
            [#local destinationLink = baselineLinks["OpsData"]]
            [#if accessLogging["aws:DestinationLink"].Enabled && accessLogging["aws:DestinationLink"].Configured]
                [#local destinationLink = getLinkTarget(occurrence, accessLogging["aws:DestinationLink"])]
            [/#if]

            [#-- Ensure records end with a delimiter - this carries through to S3 --]
            [#local accessLogFormat += "\n" ]

            [@setupLoggingFirehoseStream
                occurrence=occurrence
                componentSubset="apigateway"
                resourceDetails=accessLogStreamingResources
                destinationLink=destinationLink
                bucketPrefix="APIGatewayAccess"
                cloudwatchEnabled=true
                cmkKeyId=kmsKeyId
                loggingProfile=loggingProfile
            /]

        [/#if]

        [#-- If Access logs are intended for CloudWatch or the existing log groups should remain ...    --]
        [#-- This is intended to allow existing products to allow progressive updates to their logging. --]
        [#-- If Firehose is enabled, LogGroup will not receive new logs and serve as records only.      --]
        [#if !accessLogging["aws:KinesisFirehose"] || accessLogging["aws:KeepLogGroup"] ]
            [#-- Add CloudWatch LogGroup --]
            [@setupLogGroup
                occurrence=occurrence
                logGroupId=accessLgId
                logGroupName=accessLgName
                loggingProfile=loggingProfile
                kmsKeyId=kmsKeyId
            /]
        [/#if]
    [/#if]

    [#-- hamlet doesn't create the execution log group, but can manage any subscriptions   --]
    [#-- Note that subscriptions will only be created on the second and subsequent stack   --]
    [#-- execution, i.e. when the epilogue script has been successfully run at least once. --]
    [#if getExistingReference(executionLgId)?has_content]
        [@createLogSubscriptionFromLoggingProfile
            occurrence=occurrence
            logGroupId=executionLgId
            logGroupName=executionLgName
            loggingProfile=loggingProfile
        /]
    [#else]
        [@warn
            message="The API gateway must be run at least twice if log subscriptions are required"
        /]
    [/#if]

    [#if deploymentSubsetRequired("apigateway", true)]
        [#-- Assume extended openAPI specification is in the ops bucket --]
        [@cfResource
            id=apiId
            type="AWS::ApiGateway::RestApi"
            properties=
                {
                    "BodyS3Location" : {
                        "Bucket" : operationsBucket,
                        "Key" : openapiFileLocation
                    },
                    "Name" : apiName,
                    "Parameters" : {
                        "basepath" : solution.BasePathBehaviour
                    }
                } +
                attributeIfTrue(
                    "EndpointConfiguration",
                    isRegionalEndpointType,
                    {
                        "Types" : [endpointType]
                    }
                ) +
                attributeIfTrue(
                    "EndpointConfiguration",
                    isPrivateEndpointType,
                    {
                        "Types" : [endpointType]
                    } +
                    attributeIfContent(
                        "VpcEndpointIds",
                        sourceVPCEndpoints
                    )
                ) +
                attributeIfContent(
                    "Policy",
                    apiPolicyStatements,
                    getPolicyDocumentContent(apiPolicyStatements)
                ) +
                attributeIfTrue(
                    "DisableExecuteApiEndpoint",
                    customDomainResources?has_content,
                    true
                )
            outputs=APIGATEWAY_OUTPUT_MAPPINGS
            tags=getOccurrenceTags(occurrence, {"Name": apiName})
        /]

        [@cfResource
            id=deployId
            type="AWS::ApiGateway::Deployment"
            properties=
                {
                    "RestApiId": getReference(apiId),
                    "StageName": "default"
                }
            outputs={}
        /]

        [#-- Throttling Configuration --]
        [#local methodSettings = [
            {
                "HttpMethod": "*",
                "ResourcePath": "/*",
                "LoggingLevel": "INFO",
                "DataTraceEnabled": true
            } +
            attributeIfContent(
                "ThrottlingBurstLimit",
                (openapiIntegrations.Throttling.BurstLimit)!""
            ) +
            attributeIfContent(
                "ThrottlingRateLimit",
                (openapiIntegrations.Throttling.RateLimit)!""
            )
        ]]

        [#-- Integration Patterns (as Regex) into Matching Method Throttling (as explicit paths) --]
        [#if openapiDefinition?has_content]
            [#list openapiDefinition.paths as path,pathConfig]
                [#list pathConfig?keys as verb]
                    [#list openapiIntegrations.Patterns![] as pattern]
                        [#if path?matches( (pattern.Path)!"" ) && verb?matches( (pattern.Verb)!"" )]
                            [#if pattern.Throttling?has_content]
                                [#local methodSettings +=
                                [
                                    {
                                        "ResourcePath" : path,
                                        "HttpMethod": verb
                                    } +
                                    attributeIfContent("ThrottlingBurstLimit", (pattern.Throttling.BurstLimit)!"") +
                                    attributeIfContent("ThrottlingRateLimit", (pattern.Throttling.RateLimit)!"")
                                ]]
                            [/#if]
                        [/#if]
                    [/#list]
                [/#list]
            [/#list]
        [/#if]

        [@cfResource
            id=stageId
            type="AWS::ApiGateway::Stage"
            properties=
                {
                    "DeploymentId" : getReference(deployId),
                    "RestApiId" : getReference(apiId),
                    "StageName" : stageName,
                    "AccessLogSetting" : {
                        "DestinationArn" : getArn(stageLogTarget),
                        "Format" : accessLogFormat
                    }
                } +
                attributeIfContent("MethodSettings", methodSettings) +
                attributeIfContent("Variables", stageVariables) +
                attributeIfTrue(
                    "TracingEnabled",
                    solution.Tracing.Configured && solution.Tracing.Enabled && ((solution.Tracing.Mode!"") == "active"),
                    true)
            outputs={}
            tags=getOccurrenceTags(occurrence, {"Name": stageName})
        /]

        [#-- Create a CloudFront distribution if required --]
        [#if cfResources?has_content]

            [#local cachePolicy = cfResources["cachePolicy"] ]
            [#local originRequestPolicy = cfResources["originRequestPolicy"]]

            [@createCFCachePolicy
                id=cachePolicy.Id
                name=cachePolicy.Name
                ttl={
                    "Min": 0,
                    "Max": 0,
                    "Default": 0
                }
                headerNames=[] cookieNames=[]
                queryStringNames=[] compressionProtocols=[]
            /]

            [@createCFOriginRequestPolicy?with_args(
                getOriginRequestPolicy(
                    "originRequestPolicy",
                    "LinkType",
                    occurrence.Core.Type,
                    [],
                    [],
                    combineEntities(
                        _context.ForwardHeaders![],
                        solution.CloudFront.CustomHeaders,
                        UNIQUE_COMBINE_BEHAVIOUR
                    ) +
                    valueIfTrue(
                        ["Host"],
                        endpointType == "REGIONAL",
                        []
                    ),
                    []
                )
            ) id=originRequestPolicy.Id name=originRequestPolicy.Name /]

            [#local origin =
                getCFHTTPOrigin(
                    cfResources["origin"].Id,
                    valueIfTrue(
                        cfResources["origin"].Fqdn,
                        customDomainResources?has_content,
                        {
                            "Fn::Join" : [
                                ".",
                                [
                                    getReference(apiId),
                                    "execute-api." + getRegion() + ".amazonaws.com"
                                ]
                            ]
                        }
                    ),
                    getCFHTTPHeader(
                        "x-api-key",
                        getOccurrenceSettingValue(
                            occurrence,
                            ["APIGateway","API","AccessKey"]
                        )
                    )
                )
            ]

            [#local defaultCacheBehaviour =
                getCFCacheBehaviour(
                    origin,
                    cachePolicy.Id,
                    "",
                    [ "DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT" ],
                    [ "GET", "HEAD" ],
                    solution.CloudFront.Compress,
                    [],
                    originRequestPolicy.Id,
                    "",
                    securityProfile.ProtocolPolicy
                )
            ]

            [#local restrictions = {} ]
            [#local whitelistedCountryCodes = getGroupCountryCodes(solution.CloudFront.CountryGroups![], false) ]
            [#if whitelistedCountryCodes?has_content]
                [#local restrictions = getCFGeoRestriction(whitelistedCountryCodes, false) ]
            [#else]
                [#local blacklistedCountryCodes = getGroupCountryCodes(solution.CloudFront.CountryGroups![], true) ]
                [#if blacklistedCountryCodes?has_content]
                    [#local restrictions = getCFGeoRestriction(blacklistedCountryCodes, true) ]
                [/#if]
            [/#if]

            [@createCFDistribution
                id=cfResources["distribution"].Id
                dependencies=stageId
                aliases=cfResources["distribution"].Fqdns![]
                certificate=valueIfContent(
                    getCFCertificate(
                        cfResources["distribution"].CertificateId,
                        securityProfile.CDNHTTPSProfile,
                        solution.CloudFront.AssumeSNI),
                    cfResources["distribution"].CertificateId!"")
                comment=cfResources["distribution"].Name
                defaultCacheBehaviour=defaultCacheBehaviour
                logging=valueIfTrue(
                    getCFLogging(
                        operationsBucket,
                        formatComponentAbsoluteFullPath(
                            core.Tier,
                            core.Component,
                            occurrence
                        )
                    ),
                    solution.CloudFront.EnableLogging)
                origins=origin
                restrictions=restrictions
                wafAclId=(wafAclResources.acl.Id)!""
                tags=getOccurrenceTags(occurrence)
            /]

            [@createAPIUsagePlan
                id=cfResources["usageplan"].Id
                name=cfResources["usageplan"].Name
                stages=[
                    {
                        "ApiId" : getReference(apiId),
                        "Stage" : stageName
                    }
                ]
                dependencies=stageId
                tags=getOccurrenceTags(occurrence)
            /]
        [/#if]

        [#list customDomainResources as key,value]
            [@cfResource
                id=value["domain"].Id
                type="AWS::ApiGateway::DomainName"
                properties=
                    {
                        "DomainName" : value["domain"].Name,
                        "SecurityPolicy" : securityProfile.GatewayHTTPSProfile
                    } +
                    valueIfTrue(
                        {
                            "RegionalCertificateArn":
                                contentIfContent(
                                    getArn(value["domain"].CertificateId, true, getRegion())
                                    "HamletFatal: Could not find certificate " + value["domain"].CertificateId
                                ),
                            "EndpointConfiguration" : {
                                "Types" : [endpointType]
                            }
                        },
                        isRegionalEndpointType,
                        {
                            "CertificateArn":
                                contentIfContent(
                                    getArn(value["domain"].CertificateId, true, "us-east-1"),
                                    "HamletFatal: Could not find certificate " + value["domain"].CertificateId
                                )
                        }
                    ) +
                    valueIfTrue(
                        {
                            "MutualTlsAuthentication" : {
                                "TruststoreUri" : mutualTLSTrustStore
                            }
                        },
                        mutualTLS,
                        {}
                    )
                outputs={}
                dependencies=apiId
                tags=getOccurrenceTags(occurrence, {"Name": value["domain"].Name})
            /]
            [@cfResource
                id=value["basepathmapping"].Id
                type="AWS::ApiGateway::BasePathMapping"
                properties=
                    {
                        "DomainName" : value["domain"].Name,
                        "RestApiId" : getReference(apiId)
                    } +
                    attributeIfContent("Stage", value["basepathmapping"].Stage)
                outputs={}
                dependencies=[ value["domain"].Id, stageId ]
            /]
        [/#list]

        [#list (solution.Alerts?values)?filter(x -> x.Enabled) as alert ]

            [#local monitoredResources = getCWMonitoredResources(core.Id, resources, alert.Resource)]
            [#list monitoredResources as name,monitoredResource ]

                [@debug message="Monitored resource" context=monitoredResource enabled=false /]

                [#switch alert.Comparison ]
                    [#case "Threshold" ]
                        [@createAlarm
                            id=formatDependentAlarmId(monitoredResource.Id, alert.Id )
                            severity=alert.Severity
                            resourceName=core.FullName
                            alertName=alert.Name
                            actions=getCWAlertActions(occurrence, solution.Profiles.Alert, alert.Severity )
                            metric=getCWMetricName(alert.Metric, monitoredResource.Type, core.ShortFullName)
                            namespace=getCWResourceMetricNamespace(monitoredResource.Type, alert.Namespace)
                            description=alert.Description!alert.Name
                            threshold=alert.Threshold
                            statistic=alert.Statistic
                            evaluationPeriods=alert.Periods
                            period=alert.Time
                            operator=alert.Operator
                            reportOK=alert.ReportOk
                            unit=alert.Unit
                            missingData=alert.MissingData
                            dimensions=getCWMetricDimensions(alert, monitoredResource, resources, stageVariables)
                        /]
                    [#break]
                [/#switch]
            [/#list]
        [/#list]

        [#list resources.logMetrics!{} as logMetricName,logMetric ]

            [@createLogMetric
                id=logMetric.Id
                name=logMetric.Name
                logGroup=logMetric.LogGroupName
                filter=getReferenceData(LOGFILTER_REFERENCE_TYPE)[logMetric.LogFilter].Pattern
                namespace=getCWResourceMetricNamespace(logMetric.Type)
                value=1
                dependencies=logMetric.LogGroupId
            /]

        [/#list]
    [/#if]

    [#-- Create a WAF ACL if required --]
    [#if wafAclResources?has_content ]

        [#local wafRegional = isRegionalEndpointType && (!cfResources?has_content) ]

        [#-- WAF Logging --]
        [#-- WAF Can only log to a Kinesis Firehose --]
        [#if wafLogStreamingResources?has_content ]

            [@setupLoggingFirehoseStream
                occurrence=occurrence
                componentSubset=APIGATEWAY_COMPONENT_TYPE
                resourceDetails=wafLogStreamingResources
                destinationLink=baselineLinks["OpsData"]
                bucketPrefix="WAF"
                cloudwatchEnabled=true
                cmkKeyId=kmsKeyId
                loggingProfile=loggingProfile
            /]

            [@enableWAFLogging
                wafaclId=wafAclResources.acl.Id
                wafaclArn=wafAclResources.acl.Arn
                componentSubset=APIGATEWAY_COMPONENT_TYPE
                deliveryStreamId=wafLogStreamingResources["stream"].Id
                deliveryStreamArns=[ wafLogStreamingResources["stream"].Arn ]
                regional=wafRegional
            /]

        [/#if]

        [#if deploymentSubsetRequired(APIGATEWAY_COMPONENT_TYPE, true)]
            [@createWAFAclFromSecurityProfile
                id=wafAclResources.acl.Id
                name=wafAclResources.acl.Name
                metric=wafAclResources.acl.Name
                wafSolution=solution.WAF
                securityProfile=securityProfile
                occurrence=occurrence
                regional=wafRegional
            /]

            [#if !cfResources?has_content]
                [#-- Attach to API Gateway if no CloudFront distribution --]
                [@createWAFAclAssociation
                    id=wafAclResources.association.Id
                    wafaclId=wafAclResources.acl.Arn
                    endpointId=
                        formatRegionalArn(
                            "apigateway",
                            {
                                "Fn::Join": [
                                    "/",
                                    [
                                        "/restapis",
                                        getReference(apiId),
                                        "stages",
                                        stageName
                                    ]
                                ]
                            }
                        )
                    dependencies=stageId
                /]
            [/#if]
        [/#if]
    [/#if]



    [#-- API Docs have been deprecated - keeping the S3 clear makes sure we can delete the buckets --]
    [#local docs = resources["docs"]!{} ]
    [#list docs as key,value]

        [#if deploymentSubsetRequired("prologue", false)  ]
            [#-- Clear out bucket content if deleting api gateway so buckets will delete --]
            [#if getExistingReference(value["bucket"].Id)?has_content ]
                [@addToDefaultBashScriptOutput
                    content=
                        [
                            "clear_bucket_files=()"
                        ] +
                        syncFilesToBucketScript(
                            "clear_bucket_files",
                            getRegion(),
                            value["bucket"].Name,
                            ""
                        )
                /]
            [/#if]

            [@addToDefaultBashScriptOutput
                content=
                    [
                        "error \" API Docs publishing has been deprecated \"",
                        "error \" Please remove the Publish configuration from your API Gateway\"",
                        "error \" API Publishers are now available to provide documentation publishing\""
                    ]
            /]
        [/#if]
    [/#list]

    [#-- Send API Specification to an external publisher --]

    [#if solution.Publishers?has_content ]
        [#if deploymentSubsetRequired("epilogue", false ) ]
            [@addToDefaultBashScriptOutput
                content=
                [
                    "case $\{STACK_OPERATION} in",
                    "  create|update)",
                    "   # Fetch the apidoc file",
                    "   info \"Building API Specification Document\"",
                    "   copyFilesFromBucket" + " " +
                        getRegion() + " " +
                        operationsBucket + " " +
                        openapiFileLocation + " " +
                    "   \"$\{tmpdir}\" || return $?"
                    "   ;;",
                    " esac"
                ]
            /]
        [/#if]

        [#list solution.Publishers as id,publisher ]

            [#-- Skip any disabled publishers --]
            [#if !publisher.Enabled ]
                [#continue]
            [/#if]

            [#local publisherLinks = getLinkTargets(occurrence, publisher.Links )]

            [#local publisherPath = getContextPath( occurrence, publisher.Path )]
            [#if publisher.UsePathInName ]
                [#local fileName = formatName( publisherPath, "${image.Format}.json") ]
                [#local publisherPath = "" ]
            [#else]
                [#local fileName = "${image.Format}.json" ]
            [/#if]

            [#list publisherLinks as publisherLinkId, publisherLinkTarget ]
                [#local publisherLinkTargetCore = publisherLinkTarget.Core ]
                [#local publisherLinkTargetAttributes = publisherLinkTarget.State.Attributes ]

                [#switch publisherLinkTargetCore.Type ]
                    [#case CONTENTHUB_HUB_COMPONENT_TYPE ]
                        [#if deploymentSubsetRequired("epilogue", false ) ]
                            [@addToDefaultBashScriptOutput
                                content=
                                [
                                    "case $\{STACK_OPERATION} in",
                                    "  create|update)",
                                    "info \"Sending API Specification to " + id + "-" + publisherLinkTargetCore.FullName + "\"",
                                    " cp \"$\{tmpdir}/" + openapiFileName + "\" \"$\{tmpdir}/" + fileName + "\" || return $?",
                                    "  copy_contentnode_file \"$\{tmpdir}/" + fileName + "\" " +
                                    "\"" +    publisherLinkTargetAttributes.ENGINE + "\" " +
                                    "\"" +    publisherLinkTargetAttributes.REPOSITORY + "\" " +
                                    "\"" +    publisherLinkTargetAttributes.PREFIX + "\" " +
                                    "\"" +    publisherPath + "\" " +
                                    "\"" +    publisherLinkTargetAttributes.BRANCH + "\" " +
                                    "\"update\" || return $? ",
                                    "       ;;",
                                    " esac"
                                ]
                            /]
                        [/#if]
                        [#break]
                [/#switch]
            [/#list]
        [/#list]
    [/#if]

    [#local legacyId = formatS3Id(core.Id, APIGATEWAY_COMPONENT_DOCS_EXTENSION) ]
    [#if getExistingReference(legacyId)?has_content && deploymentSubsetRequired("prologue", false) ]
        [#-- Remove legacy docs bucket id - it will likely be recreated with new id format --]
        [#-- which uses bucket name --]
        [@addToDefaultBashScriptOutput
            content=
                [
                    "clear_bucket_files=()"
                ] +
                syncFilesToBucketScript(
                    "clear_bucket_files",
                    getRegion(),
                    getExistingReference(legacyId, NAME_ATTRIBUTE_TYPE),
                    ""
                ) +
                [
                    "deleteBucket" + " " +
                        getRegion() + " " +
                        getExistingReference(legacyId, NAME_ATTRIBUTE_TYPE) + " " +
                        "|| return $?"
                ]
        /]
    [/#if]

    [#if deploymentSubsetRequired("pregeneration", false)]
        [#if image.Source == "url" ]
            [@addToDefaultBashScriptOutput
                content=getAWSImageFromUrlScript(image, true)
            /]
        [/#if]

        [#if
            ["url", "registry", "Local"]?seq_contains(image.Source) ||
            ((image.Source == "link") && (image.RegistryType == "s3")) ]
            [@addToDefaultBashScriptOutput
                content=
                    getAWSImageBuildScript(
                        "openapiFiles",
                        getRegion(),
                        image
                    ) +
                    [
                        "get_openapi_definition_file" + " " +
                                "\"" + buildRegistry + "\"" + " " +
                                "\"$\{openapiFiles[0]}\"" + " " +
                                "\"" + core.Id + "\"" + " " +
                                "\"" + core.Name + "\"" + " " +
                                "\"" + accountId + "\"" + " " +
                                "\"" + accountObject.ProviderId + "\"" + " " +
                                "\"" + getRegion() + "\"" + " || return $?",
                        "#"

                    ]
            /]
        [/#if]
    [/#if]

    [#if openapiDefinition?has_content ]
        [#if openapiDefinition["x-amazon-apigateway-request-validator"]?? ]
            [#-- Pass definition through - it is legacy and has already has been processed --]
            [#local extendedOpenapiDefinition = openapiDefinition ]
        [#else]
            [#local openapiIntegrations = getOccurrenceSettingValue(occurrence, [["apigw"], ["Integrations"]], true) ]
            [#if !openapiIntegrations?has_content]
                [@fatal
                    message="API Gateway integration definitions not found"
                    context=occurrence
                /]
                [#local openapiIntegrations = {} ]
            [/#if]
            [#if openapiIntegrations?is_hash]
                [#local openapiContext =
                    {
                        "Account" : accountObject.ProviderId,
                        "Region" : getRegion(),
                        "CognitoPools" : cognitoPools,
                        "LambdaAuthorizers" : lambdaAuthorizers,
                        "PrivateHTTPEndpoints" : privateHTTPEndpoints,
                        "FQDN" : attributes["FQDN"],
                        "Scheme" : attributes["SCHEME"],
                        "BasePath" : attributes["BASE_PATH"],
                        "BuildReference" : buildReference,
                        "Name" : apiName
                    } ]

                [#-- Determine if there are any roles required by specific methods --]
                [#local extendedOpenapiRoles = getOpenapiDefinitionRoles(openapiDefinition, openapiIntegrations) ]
                [#list extendedOpenapiRoles as path,policies]
                    [#local openapiRoleId = formatDependentRoleId(stageId, formatId(path))]
                    [#-- Roles must be defined in a separate unit so the ARNs are available here --]
                    [#if deploymentSubsetRequired("iam", false)  &&
                        isPartOfCurrentDeploymentUnit(openapiRoleId)]
                        [@createRole
                            id=openapiRoleId
                            trustedServices="apigateway.amazonaws.com"
                            policies=policies
                            tags=getOccurrenceTags(occurrence)
                        /]
                    [/#if]
                    [#local openapiContext +=
                        {
                            formatAbsolutePath(path,"rolearn") : getArn(openapiRoleId, true)
                        } ]
                [/#list]

                [#-- Generate the extended openAPI specification --]
                [#local extendedOpenapiDefinition =
                    extendOpenapiDefinition(
                        openapiDefinition,
                        openapiIntegrations,
                        openapiContext,
                        true) ]

            [#else]
                [#local extendedOpenapiDefinition = {} ]
                [@fatal
                    message="API Gateway integration definitions should be a hash"
                    context={ "Integrations" : openapiIntegrations}
                /]
            [/#if]
        [/#if]

        [#if extendedOpenapiDefinition?has_content]
            [#if deploymentSubsetRequired("config", false)]
                [@addToDefaultJsonOutput content=extendedOpenapiDefinition /]
            [/#if]
        [/#if]
    [/#if]

    [#if deploymentSubsetRequired("prologue", false)]
        [#-- Copy the final openAPI definition to the ops bucket --]
        [#-- Don't remove older versions in case the stack needs to be rolled back --]
        [@addToDefaultBashScriptOutput
            content=
                getLocalFileScript(
                    "configFiles",
                    "$\{CONFIG}",
                    openapiFileName
                ) +
                syncFilesToBucketScript(
                    "configFiles",
                    getRegion(),
                    operationsBucket,
                    formatRelativePath(
                        getOccurrenceSettingValue(occurrence, "SETTINGS_PREFIX"),
                        "config"),
                    false
                )
        /]
    [/#if]

    [#if deploymentSubsetRequired("epilogue", false)]
        [#-- Assume stack update was successful so delete other files --]
        [@addToDefaultBashScriptOutput
            content=
                getLocalFileScript(
                    "configFiles",
                    "$\{CONFIG}",
                    openapiFileName
                ) +
                syncFilesToBucketScript(
                    "configFiles",
                    getRegion(),
                    operationsBucket,
                    formatRelativePath(
                        getOccurrenceSettingValue(occurrence, "SETTINGS_PREFIX"),
                        "config"),
                    true
                )
        /]

        [#local lgResourceSetActive = false]

        [#-- Check if lg resource set is active --]
        [#list ((getDeploymentGroupDetails(getDeploymentGroup()).ResourceSets)!{})?values?filter(s -> s.Enabled ) as resourceSet ]
            [#if resourceSet["deployment:Unit"] == "lg"]
                [#local lgResourceSetActive = true]
                [#break]
            [/#if]
        [/#list]


        [#local lgLookupName = [
                "API-Gateway-Execution-Logs_",
                r'${api_id}',
                "/",
                stageName
            ]?join("")]

        [#-- Save the execution log group as a pseudo stack          --]
        [#-- Because the log group name includes the apiId, it isn't --]
        [#-- possible to pre-create it in the same way as the access --]
        [#-- log.                                                    --]
        [@addToDefaultBashScriptOutput
            content=
            [
                r'case ${STACK_OPERATION} in',
                r'  create|update)'
            ] +
            pseudoStackOutputScript(
                    "Execution Log Group",
                    {
                        executionLgId : executionLgName,
                        [#-- The deployment unit is set to match the template  --]
                        [#-- in which the log group would have been created if --]
                        [#-- that was supported by cloud formation. This       --]
                        [#-- ensures any log subscriptions for the execution   --]
                        [#-- log are created in the same place as the other    --]
                        [#-- log group configuration                           --]
                        "DeploymentUnit" :
                            valueIfTrue(
                                "lg",
                                lgResourceSetActive,
                                getCLODeploymentUnit()
                            )
                    },
                    "execlg"
            ) +
            [#-- Set the log retention otherwise the log never expires --]
            [
                r'      api_id="$(get_cloudformation_stack_output "' + getRegion() + r'" "${STACK_NAME}" "' + apiId + r'" "ref" || return $?)"',
                '       set_cloudwatch_log_group_retention "' + getRegion() + '" "' + lgLookupName + '" "' + operationsExpiration?c + '" || return $?',
                "       ;;",
                "       esac"
            ]
        /]

        [#-- If using an authoriser, give it a copy of the openapi spec --]
        [#-- Also include the definition because authorizers can't have --]
        [#-- scopes but the authorizer relies on them. Thus give it the --]
        [#-- definition file rather than the extended file              --]
        [#if lambdaAuthorizers?has_content]
            [#-- Copy the config file to a standard filename --]
            [@addToDefaultBashScriptOutput
                content=
                    getLocalFileScript(
                        "referenceFiles",
                        "$\{CONFIG}",
                        "openapi.json"
                    ) +
                    [
                        "DEFINITION_FILE=$( get_openapi_definition_filename " +
                                "\"" + core.Name + "\"" + " " +
                                "\"" + accountId + "\"" + " " +
                                "\"" + getRegion() + "\"" + " )",
                        "#"
                    ] +
                    getLocalFileScript(
                        "referenceFiles",
                        "$\{DEFINITION_FILE}",
                        "openapi-definition.json"
                    )
            /]
            [#list lambdaAuthorizers?values as lambdaAuthorizer]
                [@addToDefaultBashScriptOutput
                    content=
                        syncFilesToBucketScript(
                            "referenceFiles",
                            getRegion(),
                            operationsBucket,
                            formatRelativePath(
                                lambdaAuthorizer.SettingsPrefix,
                                "reference"),
                            false
                        )
                /]
            [/#list]
        [/#if]
    [/#if]
[/#macro]

[#------------------------------
-- Internal support functions --
--------------------------------]

[#-- Modify the definition file to meet AWS constraints --]
[#function internalEnsureAWSDefinitionCompatability content mappings={} ]

    [#local result = content ]

    [#local modelMappings = mappings ]

    [#if result?is_hash]
        [#-- Model names can only be alphanumeric --]
        [#local models = (content.components.schemas)!(content.definitions)!{} ]
        [#if models?has_content]
            [#-- See if any models need mapping --]
            [#local newModels = {} ]
            [#list models as key, value]
                [#local newKey = replaceAlphaNumericOnly(key) ]
                [#if newKey == key]
                    [#local newModels += { key : value } ]
                [#else]
                    [#local newModels += { newKey : value } ]
                    [#-- Remember the strings that have been modified --]
                    [#local modelMappings += { key, newKey } ]
                [/#if]
            [/#list]

            [#-- Update the models --]
            [#if (result.components.schemas)??]
                [#local result +=
                    {
                        "components" :
                            result.components +
                            {
                                "schemas" : newModels
                            }
                    }
                ]
            [#else]
                [#local result += { "definitions" : newModels} ]
            [/#if]
        [/#if]

        [#-- Remove unsupported attributes --]
        [#local newResult = {} ]
        [#list result as key,value]
            [#switch key]
                [#case "responses"]
                    [#-- Strip out any default response definition --]
                    [#local newResult += { key : internalEnsureAWSDefinitionCompatability(removeObjectAttributes(value, "default"), modelMappings)}]
                    [#break]
                [#case "discriminator"]
                [#case "example"]
                [#case "format"]
                [#case "enum"]
                [#case "readOnly"]
                [#case "exclusiveMinimum"]
                    [#break]
                [#default]
                    [#local newResult += { key : internalEnsureAWSDefinitionCompatability(value, modelMappings)}]
            [/#switch]
        [/#list]
        [#local result = newResult ]
    [#else]
        [#if result?is_sequence]
            [#local newResult = [] ]
            [#list result as item]
                [#local newResult += [internalEnsureAWSDefinitionCompatability(item, modelMappings)] ]
            [/#list]
            [#local result = newResult ]
        [#else]
            [#if result?is_string]
                [#-- Replace any model names with their modified values --]
                [#list modelMappings as key, value]
                    [#if result?contains(key) ]
                        [#local result = result?replace(key, value) ]
                        [#break]
                    [/#if]
                [/#list]
            [/#if]
        [/#if]
    [/#if]

    [#return result]
[/#function]
