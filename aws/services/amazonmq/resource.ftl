[#ftl]

[#assign AMAZONMQ_BROKER_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        DNS_ATTRIBUTE_TYPE : {
            "Attribute" : "AmqpEndpoints"
        },
        ARN_ATTRIBUTE_TYPE : {
            "Attribute" : "Arn"
        }
    }
]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_AMAZONMQ_BROKER_RESOURCE_TYPE
    mappings=AMAZONMQ_BROKER_OUTPUT_MAPPINGS
/]


[#function getAmazonMqMaintenanceWindow dayofWeek timeofDay timeZone="UTC" ]
    [#return
        {
            "DayOfWeek" : String,
            "TimeOfDay" : String,
            "TimeZone" : timeZone
        }
    ]
[/#function]

[#function getAmazonMqUser username password ]
    [#return
        {
            "Username" : username,
            "Password" : password
        }
    ]
[/#function]

[#macro createAmazonMqBroker id
            engineType
            engineVersion
            instanceType
            multiAz
            encrypted
            kmsKeyId
            subnetIds
            securityGroupId
            brokerTags
            users=[]
            autoMinorVersionUpdate=false
            logging=true
            maintenanceWindow={}
            dependencies=[]  ]

    [#switch engineType?lower_case ]
        [#case "rabbit" ]
        [#case "rabbitmq" ]
            [#local engineType = "RABBITMQ" ]
            [#break]

        [#default]
            [@fatal message="Unkown AmazonMq Broker Engine" context={ "id" : id, "engineType" : engineType } /]
    [/#switch]

    [@cfResource
        id=id
        type="AWS::AmazonMQ::Broker"
        properties={
            "SubnetIds" : getReferences(subnetIds),
            "SecurityGroups" : [ getReference(AWS_PROVIDER, securityGroupId) ],
            "Users" : asArray(users),
            "Logs" : {
                "General" : logging
            },
            "EngineType" : engineType,
            "EngineVersion" : engineVersion,
            "AutoMinorVersionUpgrade" : autoMinorVersionUpdate,
            "DeploymentMode" : multiAz?then(
                                "CLUSTER_MULTI_AZ",
                                "SINGLE_INSTANCE"
            ),
            "HostInstanceType" : instanceType,
            "MaintenanceWindowStartTime" : maintenanceWindow
        } +
        attributeIfTrue(
            "EncryptionOptions",
            encrypted,
            {
                "KmsKeyId" : getReference(AWS_PROVIDER, kmsKeyId),
                "UseAwsOwnedKey" : true
            }
        )
        outputs=AMAZONMQ_BROKER_OUTPUT_MAPPINGS
        dependencies=dependencies
        tags=brokerTags
    /]
[/#macro]
