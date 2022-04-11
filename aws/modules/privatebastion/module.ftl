[#ftl]

[@addModule
    name="privatebastion"
    description="Bastion access via SSM only"
    provider=AWS_PROVIDER
    properties=[
        {
            "Names" : "tier",
            "Type" : STRING_TYPE,
            "Description" : "The tier to use to host the private bastion",
            "Default" : "msg"
        },
        {
            "Names" : "component",
            "Type" : STRING_TYPE,
            "Description" : "The component to use to host the private bastion",
            "Default" : "ssh"
        },
        {
            "Names" : "deploymentUnit",
            "Type" : STRING_TYPE,
            "Description" : "The deployment unit for the private bastion",
            "Default" : "ssh"
        },
        {
            "Names" : "multiAZ",
            "Type" : BOOLEAN_TYPE,
            "Description" : "Multi-AZ support on the private bastion",
            "Default" : true
        }
    ]
/]

[#macro aws_module_privatebastion
            tier
            component
            deploymentUnit
            multiAZ ]

    [@loadModule
        blueprint={
            "Tiers" : {
                tier : {
                    "Components" : {
                        component: {
                            "bastion": {
                                "deployment:Unit": deploymentUnit,
                                "MultiAZ": multiAZ,
                                "AutoScaling": {
                                    "DetailedMetrics": false,
                                    "ActivityCooldown": 180,
                                    "MinUpdateInstances": 0,
                                    "AlwaysReplaceOnUpdate": false
                                },
                                "Permissions": {
                                    "Decrypt": true
                                }
                            }
                        }
                    }
                },
                "mgmt" : {
                    "Components" : {
                        "ssh": {
                            "Enabled": false
                        }
                    }
                }
            },
            "NetworkProfiles": {
                "default": {
                    "BaseSecurityGroup": {
                        "Links": {
                            "sshBastion": {
                                "Tier": tier,
                                "Component": component,
                                "Instance": "",
                                "Version": "",
                                "Direction": "inbound",
                                "Role": "networkacl"
                            }
                        }
                    }
                }
            }
        }
    /]
[/#macro]
