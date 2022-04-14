[#ftl]

[@addModule
    name="certificateauthority"
    description="Testing module for the aws certificateauthority component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_certificateauthority ]

    [#-- Base certificateauthority setup --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "dir" : {
                    "Components" : {
                        "certificateauthoritybase": {
                            "Type": "certificateauthority",
                            "Level": "Root",
                            "deployment:Unit": "aws-certificateauthority",
                            "Profiles" : {
                                "Testing" : [ "certificateauthoritybase" ]
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "certificateauthoritybase" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "ACMPCAAuthorityXdirXcertificateauthoritybase" : {
                                    "Name" : "ACMPCAAuthorityXdirXcertificateauthoritybase",
                                    "Type" : "AWS::ACMPCA::CertificateAuthority"
                                }
                            },
                            "Output" : [
                                "ACMPCAAuthorityXdirXcertificateauthoritybase"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "CAType" : {
                                    "Path"  : "Resources.ACMPCAAuthorityXdirXcertificateauthoritybase.Properties.Type",
                                    "Value" : "ROOT"
                                },
                                "CAType" : {
                                    "Path"  : "Resources.ACMPCAAuthorityXdirXcertificateauthoritybase.Properties.Subject.CommonName",
                                    "Value" : "certificateauthoritybase-integration"
                                },
                                "ValidityFormat": {
                                    "Path": "Resources.ACMPCACertificateXdirXcertificateauthoritybase.Properties.Validity.Type",
                                    "Value": "DAYS"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "certificateauthoritybase" : {
                    "certificateauthority" : {
                        "TestCases" : [ "certificateauthoritybase" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }
    /]

    [@loadModule
        blueprint={
            "Tiers" : {
                "dir" : {
                    "Components" : {
                        "certificateauthorityrootsub_root": {
                            "Type": "certificateauthority",
                            "deployment:Unit": "aws-certificateauthority",
                            "Level": "Root"
                        },
                        "certificateauthorityrootsub_sub": {
                            "Type": "certificateauthority",
                            "deployment:Unit": "aws-certificateauthority",
                            "Level": "Subordinate",
                            "level:Subordinate": {
                                "ParentAuthority": {
                                    "Link": {
                                        "Tier": "dir",
                                        "Component": "certificateauthorityrootsub_root"
                                    }
                                }
                            },
                            "Profiles" : {
                                "Testing" : [ "certificateauthorityrootsub" ]
                            }
                        }
                    }
                }
            },
            "TestCases" : {
                "certificateauthorityrootsub" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "ACMPCAAuthorityXdirXcertificateauthorityrootsubXroot" : {
                                    "Name" : "ACMPCAAuthorityXdirXcertificateauthorityrootsubXroot",
                                    "Type" : "AWS::ACMPCA::CertificateAuthority"
                                },
                                "ACMPCAAuthorityXdirXcertificateauthorityrootsubXsub" : {
                                    "Name" : "ACMPCAAuthorityXdirXcertificateauthorityrootsubXsub",
                                    "Type" : "AWS::ACMPCA::CertificateAuthority"
                                }
                            },
                            "Output" : [
                                "ACMPCAAuthorityXdirXcertificateauthorityrootsubXroot",
                                "ACMPCAAuthorityXdirXcertificateauthorityrootsubXsub"
                            ]
                        },
                        "JSON" : {
                            "Match" : {
                                "RootCAType" : {
                                    "Path"  : "Resources.ACMPCAAuthorityXdirXcertificateauthorityrootsubXroot.Properties.Type",
                                    "Value" : "ROOT"
                                },
                                "SubCAType" : {
                                    "Path"  : "Resources.ACMPCAAuthorityXdirXcertificateauthorityrootsubXsub.Properties.Type",
                                    "Value" : "SUBORDINATE"
                                },
                                "SubSignedByRoot" : {
                                    "Path": "Resources.ACMPCACertificateXdirXcertificateauthorityrootsubXsub.Properties.CertificateAuthorityArn",
                                    "Value": "arn:aws:iam::123456789012:mock/##MockOutputXACMPCAAuthorityXdirXcertificateauthorityrootsubXrootX##Xarn"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "certificateauthorityrootsub" : {
                    "certificateauthority" : {
                        "TestCases" : [ "certificateauthorityrootsub" ]
                    }
                }
            }
        }
    /]
[/#macro]
