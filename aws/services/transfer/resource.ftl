[#ftl]

[#assign TRANSFER_SERVER_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        NAME_ATTRIBUTE_TYPE : {
            "Attribute" : "ServerId"
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_TRANSFER_SERVER_RESOURCE_TYPE
    mappings=TRANSFER_SERVER_OUTPUT_MAPPINGS
/]

[@addCWMetricAttributes
    resourceType=AWS_TRANSFER_SERVER_RESOURCE_TYPE
    namespace="AWS/Transfer"
    dimensions={
        "server-id" : {
            "Output" : {
                "Attribute" : NAME_ATTRIBUTE_TYPE
            }
        }
    }
/]

[#function getTransferServerVpcDetails
            elasticIPIds
            subnets
            vpcId ]

    [#return
        {
            "SubnetIds" : subnets,
            "VpcId" : getReference(vpcId)
        } +
        attributeIfContent(
            "AddressAllocationIds",
            elasticIPIds,
            getReferences(elasticIPIds, ALLOCATION_ATTRIBUTE_TYPE)
        )
    ]
[/#function]

[#macro createTransferServer
            id
            protocols
            vpcDetails
            logRoleId
            securityPolicy
            certificateId=""
            dependencies=[]
            tags={}
    ]
    [@cfResource
        id=id
        type="AWS::Transfer::Server"
        properties={
                "EndpointDetails" : vpcDetails,
                "EndpointType" : "VPC",
                "IdentityProviderType" : "SERVICE_MANAGED",
                "LoggingRole" : getReference(logRoleId, ARN_ATTRIBUTE_TYPE),
                "Protocols" : asArray( protocols )?map( protocol -> protocol?upper_case),
                "SecurityPolicyName" : securityPolicy
            } +
            attributeIfContent(
                "Certificate",
                certificateId,
                getArn(certificateId)
            )
        outputs=TRANSFER_SERVER_OUTPUT_MAPPINGS
        tags=tags
        dependencies=dependencies
    /]
[/#macro]

[#function getTransferHomeDirectoryMapping entry bucketName target ]
    [#-- entry = what the user will see --]
    [#-- target = where the data is --]
    [#return
        {
            "Entry" : entry?remove_ending("/"),
            "Target"  : formatAbsolutePath( bucketName, target )?remove_ending("/")
        }
    ]
[/#function]

[#macro createTransferUser
            id
            username
            homeDirectoryMappings
            roleId
            transferServerId
            sshPublicKeys
            transferUserPolicy=""
            dependencies=[]
            tags={}
    ]

    [@cfResource
        id=id
        type="AWS::Transfer::User"
        properties={
            "UserName" : username,
            "HomeDirectoryMappings" : homeDirectoryMappings,
            "HomeDirectoryType" : "LOGICAL",
            "Role" : getArn(roleId),
            "ServerId" : getReference(transferServerId, NAME_ATTRIBUTE_TYPE),
            "SshPublicKeys" : asArray(sshPublicKeys)
        } +
        attributeIfContent(
            "Policy",
            transferUserPolicy
        )
        tags=tags
        dependencies=dependencies
    /]
[/#macro]
