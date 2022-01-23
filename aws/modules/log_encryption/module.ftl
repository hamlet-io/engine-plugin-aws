[#ftl]

[@addModule
    name="log_encryption"
    description="Enables at-rest log encryption across all components using CloudWatch Logs"
    provider=AWS_PROVIDER
    properties=[]
/]

[#macro aws_module_log_encryption ]
    [@loadModule
        blueprint={
            "DeploymentProfiles" : {
                "kms_key_logs" : {
                    "Modes" : {
                        "*" : {
                            "baselinekey" : {
                                "Extensions" : [ "cmk_logs_access" ]
                            }
                        }
                    }
                }
            },
            "LoggingProfiles" : {
                "default" : {
                    "Encryption" : {
                        "Enabled" : true
                    }
                }
            }
        }
    /]
[/#macro]
