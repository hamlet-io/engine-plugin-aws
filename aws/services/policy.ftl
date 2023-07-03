[#ftl]

[#-- Policy Structure --]

[#function getPolicyStatement actions=[] resources="*" principals="" conditions="" allow=true sid="" notprincipals="" notActions=[]]
    [#if ! ( actions?has_content || notActions?has_content) ]
        [@fatal
            message="AWS Policy Statement must have actions or notActions defined"
            context={
                "actions": actions,
                "notActions": notActions,
                "Sid": sid,
                "principals" : principals
            }
        /]
    [/#if]

    [#return
        {
            "Effect" : allow?then("Allow", "Deny")
        } +
        attributeIfContent("Action", actions)+
        attributeIfContent("NotAction", notActions) +
        attributeIfContent("Sid", sid) +
        attributeIfContent("Resource", resources) +
        attributeIfContent("Principal", principals) +
        attributeIfContent("NotPrincipal", notprincipals) +
        attributeIfContent("Condition", conditions)
    ]
[/#function]

[#function getPolicyDocumentContent statements version="2012-10-17" id=""]
    [#return
        {
            "Statement": asArray(statements),
            "Version": version
        } +
        attributeIfContent("Id", id)
    ]
[/#function]

[#function getPolicyDocument statements name=""]
    [#return
        {
            "PolicyDocument" : getPolicyDocumentContent(statements)
        }+
        attributeIfContent("PolicyName", name)
    ]
[/#function]

[#-- Conditions --]

[#function getMFAPresentCondition ]
    [#return
        {
            "Bool": {
              "aws:MultiFactorAuthPresent": "true"
            }
        }]
[/#function]

[#function getIPCondition cidrs=[] match=true]
    [#return
        {
            match?then("IpAddress", "NotIpAddress") :
                { "aws:SourceIp": asFlattenedArray(cidrs) }
        }
    ]
[/#function]

[#function getVPCEndpointCondition vpcEndpoints=[] match=true]
    [#return
        {
            match?then("StringEquals", "StringNotEquals") :
                { "aws:SourceVpce": asFlattenedArray(vpcEndpoints) }
        }
    ]
[/#function]
