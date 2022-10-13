[#ftl]

[#macro aws_lambda_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]

    [#assign componentState =
        {
            "Resources" : {
                "lambda" : {
                    "Id" : formatResourceId(AWS_LAMBDA_RESOURCE_TYPE, core.Id),
                    "Name" : core.FullName,
                    "Type" : AWS_LAMBDA_RESOURCE_TYPE
                }
            },
            "Attributes" : {},
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]
[/#macro]

[#macro aws_function_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution ]

    [#local id = formatResourceId(AWS_LAMBDA_FUNCTION_RESOURCE_TYPE, core.Id)]

    [#local region = getExistingReference(id, REGION_ATTRIBUTE_TYPE)!getRegion()]

    [#-- Unversioned lambda ARN - make available to permit linkage even if function isn't deployed --]
    [#local arn =
        formatArn(
            getRegionObject().Partition,
            "lambda",
            region,
            accountObject.ProviderId,
            "function:" + core.FullName,
            true
        )
    ]

    [#local fixedCodeVersion = {} ]
    [#if isPresent(solution.FixedCodeVersion) ]

        [#local versionOutputId = formatResourceId(AWS_LAMBDA_VERSION_RESOURCE_TYPE, core.Id) ]

        [#-- The arn changes as part of the deployment process to reflect the new version --]
        [#local arn = getExistingReference(versionOutputId) ]
        [#local fixedCodeVersion =
            {
                "version" : {
                    "Id" : versionOutputId,
                    "ResourceId" :
                        valueIfTrue(
                            formatId(versionOutputId, runId),
                            solution.FixedCodeVersion.NewVersionOnDeploy,
                            versionOutputId
                        ),
                    "Type" : AWS_LAMBDA_VERSION_RESOURCE_TYPE
                }
            }
        ]

        [#if solution.FixedCodeVersion.Alias?has_content]
            [#local aliasId = formatResourceId(AWS_LAMBDA_ALIAS_RESOURCE_TYPE, core.Id) ]
            [#local fixedCodeVersion +=
                {
                    "alias" : {
                        "Id" : aliasId,
                        "Name" : solution.FixedCodeVersion.Alias,
                        "Type" : AWS_LAMBDA_ALIAS_RESOURCE_TYPE
                    }
                }
            ]
            [#-- Alias ARN is fixed - make available to permit linkage even if function isn't deployed --]
            [#local arn =
                formatArn(
                    getRegionObject().Partition,
                    "lambda",
                    region,
                    accountObject.ProviderId,
                    ["function", core.FullName, solution.FixedCodeVersion.Alias]?join(":")
                    true
                )
            ]
        [/#if]
    [/#if]

    [#local lgId = formatLogGroupId(core.Id)]
    [#local lgName = formatAbsolutePath("aws", "lambda", core.FullName)]

    [#local securityGroupId = formatDependentSecurityGroupId(id)]

    [#local logMetrics = {} ]
    [#list solution.LogMetrics as name,logMetric ]
        [#local logMetrics += {
            "lgMetric" + name : {
                "Id" : formatDependentLogMetricId( lgId, logMetric.Id ),
                "Name" : getCWMetricName( logMetric.Name, AWS_CLOUDWATCH_LOG_METRIC_RESOURCE_TYPE, core.ShortFullName ),
                "Type" : AWS_CLOUDWATCH_LOG_METRIC_RESOURCE_TYPE,
                "LogGroupName" : lgName,
                "LogGroupId" : lgId,
                "LogFilter" : logMetric.LogFilter
            }
        }]
    [/#list]

    [#assign componentState =
        {
            "Images": constructAWSImageResource(
                occurrence,
                (solution.Image.ArchiveFormat == "zip")?then("lambda", "lambda_jar")
            ),
            "Resources" : {
                "function" : {
                    "Id" : id,
                    "Name" : core.FullName,
                    "Type" : AWS_LAMBDA_FUNCTION_RESOURCE_TYPE,
                    "Monitored" : true
                },
                "lg" : {
                    "Id" : formatLogGroupId(core.Id),
                    "Name" : lgName,
                    "Type" : AWS_CLOUDWATCH_LOG_GROUP_RESOURCE_TYPE,
                    "IncludeInDeploymentState" : false
                }
            } +
            attributeIfContent("logMetrics", logMetrics) +
            fixedCodeVersion +
            attributeIfTrue(
                "securityGroup",
                solution.VPCAccess,
                {
                    "Id" : formatDependentSecurityGroupId(id),
                    "Name" : formatName("lambda", core.FullName),
                    "Type" : AWS_VPC_SECURITY_GROUP_RESOURCE_TYPE
                }
            ),
            "Attributes" : {
                "REGION" : region,
                "ARN" : arn,
                "NAME" : core.FullName,
                "DEPLOYMENT_TYPE": solution.DeploymentType
            },
            "Roles" : {
                "Inbound" : {
                    "logwatch" : {
                        "Principal" : "logs." + region + ".amazonaws.com",
                        "LogGroupIds" : [ lgId ]
                    }
                } +
                attributeIfTrue(
                    "networkacl",
                    solution.VPCAccess,
                    {
                        "SecurityGroups" : securityGroupId,
                        "Description" : core.FullName
                    }
                ),
                "Outbound" : {
                    "default" : "invoke",
                    "invoke" : lambdaInvokePermission(id),
                    "authorise" : lambdaInvokePermission(id),
                    "authorize" : lambdaInvokePermission(id)
                }
            }
        }
    ]
[/#macro]
