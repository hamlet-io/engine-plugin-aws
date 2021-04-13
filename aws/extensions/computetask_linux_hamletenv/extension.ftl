[#ftl]

[@addExtension
    id="computetask_linux_hamletenv"
    aliases=[
        "_computetask_linux_hamletenv"
    ]
    description=[
        "Uses the shared profile configuration to set default environment varaibles"
    ]
    supportedTypes=[
        EC2_COMPONENT_TYPE,
        ECS_COMPONENT_TYPE,
        COMPUTECLUSTER_COMPONENT_TYPE,
        BASTION_COMPONENT_TYPE
    ]
    scopes=[
        COMPUTETASK_EXTENSION_SCOPE
    ]
/]

[#macro shared_extension_computetask_linux_hamletenv_deployment_computetask occurrence ]

    [#local baselineLinks = _context.BaselineLinks]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    [#local operationsBucket = getExistingReference(baselineComponentIds["OpsData"]) ]
    [#local dataBucket = getExistingReference(baselineComponentIds["AppData"])]
    [#local envVariables = getFinalEnvironment(occurrence, _context ).Environment ]

    [#local role = (occurrence.Configuration.Settings.Product["Role"].Value)!""]

    [#local envContent = [
        r'# Set environment variables from hamlet configuration',
        r'export cot_request="'       + getCLORequestReference()        + '"',
        r'export cot_configuration="' + getCLOConfigurationReference()  + '"',
        r'export cot_accountRegion="' + accountRegionId                 + '"',
        r'export cot_tenant="'        + tenantId                        + '"',
        r'export cot_account="'       + accountId                       + '"',
        r'export cot_product="'       + productId                       + '"',
        r'export cot_region="'        + regionId                        + '"',
        r'export cot_segment="'       + segmentId                       + '"',
        r'export cot_environment="'   + environmentId                   + '"',
        r'export cot_tier="'          + occurrence.Core.Tier.Id         + '"',
        r'export cot_component="'     + occurrence.Core.Component.Id    + '"',
        r'export cot_role="'          + role                            + '"',
        r'export cot_credentials="'   + credentialsBucket               + '"',
        r'export cot_code="'          + codeBucket                      + '"',
        r'export cot_logs="'          + operationsBucket                + '"',
        r'export cot_backups="'       + dataBucket                      + '"'
    ]]

    [#list envVariables as key,value]
        [#local envContent +=
            [
                'export ${key}="${value}"'
            ]
        ]
    [/#list]

    [@computeTaskConfigSection
        computeTaskTypes=[ COMPUTE_TASK_HAMLET_ENVIRONMENT_VARIABLES ]
        id="HamletEnv"
        priority=2
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content={
                "files" : {
                    "/etc/profile.d/hamlet_env.sh" : {
                        "content" : {
                            "Fn::Join" : [
                                "\n",
                                envContent
                            ]
                        },
                        "mode" : "000644"
                    }
                },
                "commands": {
                    "01Directories" : {
                        "command" : "mkdir --parents --mode=0755 /var/log/codeontap",
                        "ignoreErrors" : false
                    }
                }
            }
    /]
[/#macro]
