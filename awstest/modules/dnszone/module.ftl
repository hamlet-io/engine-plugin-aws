[#ftl]

[@addModule
    name="dnszone"
    description="Testing module for the aws dnszone component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_dnszone  ]

    [#-- Base --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "mgmt" : {
                    "Components" : {
                        "dnszonebase_private":{
                            "Type": "dnszone",
                            "deployment:Unit": "aws-dnszone",
                            "Profiles" : {
                                "Network" : "default",
                                "Testing" : [ "dnszonebase_private" ]
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "dnszonebase_private" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "privateZone" : {
                                    "Name" : "route53hostedzoneXmgmtXdnszonebaseXprivate",
                                    "Type" : "AWS::Route53::HostedZone"
                                }
                            },
                            "Output" : [
                                "route53hostedzoneXmgmtXdnszonebaseXprivate"
                            ]
                        },
                        "JSON" : {
                            "VPCDefined" : {
                                "Exists" : "Resources.route53hostedzoneXmgmtXdnszonebaseXprivate.VPCs"
                            },
                            "LocalVPCDefined" : {
                                "Match" : {
                                    "Path" : "Resources.route53hostedzoneXmgmtXdnszonebaseXprivate.VPCs[0].VpcId",
                                    "Value" : "vpc-123456789abcdef12"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "dnszonebase_private" : {
                    "dnszone" : {
                        "TestCases" : [ "dnszonebase_private" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]

[/#macro]
