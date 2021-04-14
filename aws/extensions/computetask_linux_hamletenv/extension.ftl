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
        r'export hamlet_request="'       + getCLORequestReference()        + '"',
        r'export hamlet_configuration="' + getCLOConfigurationReference()  + '"',
        r'export hamlet_accountRegion="' + accountRegionId                 + '"',
        r'export hamlet_tenant="'        + tenantId                        + '"',
        r'export hamlet_account="'       + accountId                       + '"',
        r'export hamlet_product="'       + productId                       + '"',
        r'export hamlet_region="'        + regionId                        + '"',
        r'export hamlet_segment="'       + segmentId                       + '"',
        r'export hamlet_environment="'   + environmentId                   + '"',
        r'export hamlet_tier="'          + occurrence.Core.Tier.Id         + '"',
        r'export hamlet_component="'     + occurrence.Core.Component.Id    + '"',
        r'export hamlet_role="'          + role                            + '"',
        r'export hamlet_credentials="'   + credentialsBucket               + '"',
        r'export hamlet_code="'          + codeBucket                      + '"',
        r'export hamlet_logs="'          + operationsBucket                + '"',
        r'export hamlet_backups="'       + dataBucket                      + '"'
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
