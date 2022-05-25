[#ftl]

[@addModule
    name="datafeed"
    description="Testing module for the aws datastream component"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_datafeed  ]

    [#-- Data Stream Source --]
    [@loadModule
        blueprint={
            "Tiers" : {
                "app" : {
                    "Components" : {
                        "datafeedstreamsource": {
                            "Type" : "datafeed",
                            "deployment:Unit": "aws-datafeed",
                            "Profiles" : {
                                "Testing" : [ "datafeedstreamsource" ]
                            },
                            "aws:DataStreamSource" : {
                                "Enabled" : true,
                                "Link" : {
                                    "Tier": "app",
                                    "Component" : "datafeedstreamsource-datastream"
                                }
                            },
                            "Destination" : {
                                "Link": {
                                    "Tier" : "app",
                                    "Component": "datafeedstreamsource-s3"
                                }
                            }
                        },
                        "datafeedstreamsource-datastream":{
                            "Type": "datastream",
                            "deployment:Unit": "aws-datafeed"
                        },
                        "datafeedstreamsource-s3":{
                            "Type": "s3",
                            "deployment:Unit": "aws-datafeed"
                        }
                    }
                }
            },
            "TestCases" : {
                "datafeedstreamsource" : {
                    "OutputSuffix" : "template.json",
                    "Structural" : {
                        "CFN" : {
                            "Resource" : {
                                "Firehose" : {
                                    "Name" : "firehosestreamXappXdatafeedstreamsource",
                                    "Type" : "AWS::KinesisFirehose::DeliveryStream"
                                },
                                "Stream" : {
                                    "Name" : "datastreamXappXdatafeedstreamsource",
                                    "Type" : "AWS::Kinesis::Stream"
                                }
                            },
                            "Output" : [
                                "firehosestreamXappXdatafeedstreamsource",
                                "firehosestreamXappXdatafeedstreamsourceXarn",
                                "datastreamXappXdatafeedstreamsource",
                                "datastreamXappXdatafeedstreamsourceXarn"
                            ]
                        },
                        "JSON" : {
                            "Exists" : [
                                "Resources.firehosestreamXappXdatafeedstreamsource.Properties.KinesisStreamSourceConfiguration.KinesisStreamARN"
                            ],
                            "Match" : {
                                "DeliveryStreamType" : {
                                    "Path"  : "Resources.firehosestreamXappXdatafeedstreamsource.Properties.DeliveryStreamType",
                                    "Value" : "KinesisStreamAsSource"
                                }
                            }
                        }
                    }
                }
            },
            "TestProfiles" : {
                "datafeedstreamsource" : {
                    "datafeed" : {
                        "TestCases" : [ "datafeedstreamsource" ]
                    },
                    "*" : {
                        "TestCases" : [ "_cfn-lint" ]
                    }
                }
            }
        }

        stackOutputs=[
            {
                "Account" : "0123456789",
                "Region" : "mock-region-1",
                "DeploymentUnit" : "aws-datafeed",

                "datastreamXappXdatafeedstreamsource": "mockedup-integration-application-datafeedstreamsource",
                "datastreamXappXdatafeedstreamsourceXarn" : "arn:aws:kinesis:mock-region-1:0123456789:stream/mockedup-integration-application-datafeedstreamsource",

                "s3XappXdatafeedstreamsource": "mockedup-integration-application-datafeedstreamsource-568132487",
                "s3XappXdatafeedstreamsourceXarn" : "arn:aws:s3:::mockedup-integration-application-datafeedstreamsource-568132487e"
            }
        ]
    /]

[/#macro]
