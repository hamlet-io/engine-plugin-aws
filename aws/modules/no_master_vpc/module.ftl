[#ftl]

[@addModule
    name="no_master_vpc"
    description="Disables the vpc added to the solution from masterdata"
    provider=AWS_PROVIDER
    properties=[]
/]

[#macro aws_module_no_master_vpc ]
    [@loadModule
        blueprint={
            "Tiers" : {
                "mgmt" : {
                    "Components" : {
                        "vpc" : {
                            "network" : {
                                "Enabled" : false
                            }
                        },
                        "igw" : {
                            "gateway" : {
                                "Enabled" : false
                            }
                        },
                        "vpcendpoint" : {
                            "gateway" : {
                                "Enabled" : false
                            }
                        },
                        "nat" : {
                            "gateway" : {
                                "Enabled" : false
                            }
                        },
                        "ssh" : {
                            "bastion" : {
                                "Enabled" : false
                            }
                        }
                    }
                }
            }
        }
    /]
[/#macro]
