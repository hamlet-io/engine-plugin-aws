[#ftl]

[@addModule
    name="logconsolidation"
    description="Solution-wide consolidation of logs, intended for consumption by ElasticSearch."
    provider=AWS_PROVIDER
    properties=[]
/]

[#macro aws_module_logconsolidation ]

    [@debug message="Entering Module: logconsolidation" context=layerActiveData enabled=false /]

    [@loadModule
        settingSets=[]
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "logstore" : {
                            "s3" : {
                                "Instances" : {
                                    "default" : {}
                                },
                                "Links": {
                                    "source": {
                                        "Tier": "mgmt",
                                        "Component": "baseline",
                                        "DataBucket": "opsdata",
                                        "Version": "",
                                        "Instance": "",
                                        "Role": "replicasource"
                                    }
                                },
                                "Lifecycle": {
                                    "Versioning": true
                                },
                                "Encryption": {
                                    "Enabled": true
                                }
                            }
                        }
                    }
                }
            },
            "LogFilters": {
                "all-logs": {
                    "Pattern": ""
                }
            }
        }
    /]

    [#-- TODO(rossmurr4y): feature: define placeholder log filter pattern --]
    [#-- TODO(rossmurr4y): feature: add datafeed component to module blueprint  --]
    [#-- TODO(rossmurr4y): feature: add log processor lambda function to module blueprint --]
    [#-- TODO(rossmurr4y): feature: define logging profile for forwarding logs to the log consolidation dest. bucket --]
    [#-- TODO(rossmurr4y): feature: define deploymentProfile for opsdata -> log consolidation store replication --]
    [#-- TODO(rossmurr4y): feature: define deploymentProfile to capture LB logs --]
    [#-- TODO(rossmurr4y): feature: define deploymentProfile to capture ECS service/task logs --]
    [#-- TODO(rossmurr4y): feature: define loggingprofile for use by apigw components to log to kinesis /w log processor function --]
    [#-- TODO(rossmurr4y): feature: define deploymentProfile to apply new logging profile to apigw components --]
    [#-- TODO(rossmurr4y): feature: add test case to the provider: log consolidation bucket exists --]
    [#-- TODO(rossmurr4y): feature: add test case to the provider: opsdata replication rule exists --]
    [#-- TODO(rossmurr4y): feature: add test case to the provider:  log processor exists --]
    [#-- TODO(rossmurr4y): feature: add test case to the provider: datafeed exists and uses log processor --]
    [#-- TODO(rossmurr4y): feature: add test case to the provider: mocked apigw exists and logs to a firehose --]
    [#-- TODO(rossmurr4y): feature: add test case to the provider: mocked LB exists and has loadbalancerattributes enabling logs --]
    [#-- TODO(rossmurr4y): feature: add test profile to module --]
    
[/#macro]