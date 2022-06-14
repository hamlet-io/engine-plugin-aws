[#ftl]

[@addDynamicValueProvider
    type=AWS_SECRET_DYNAMIC_VALUE_TYPE
    properties=[
        {
            "Type"  : "Description",
            "Value" : "Returns a reference to a secret stored in a secretstore"
        }
    ]
    parameterOrder=["linkId", "jsonKey", "version" ]
    parameterAttributes=[
        {
            "Names" : "linkId",
            "Description" : "The Id of the link to the secret",
            "Types" : STRING_TYPE,
            "Mandatory" : true
        },
        {
            "Names" : "jsonKey",
            "Description" : "If the secret is a json object the key of the value to return",
            "Types" : STRING_TYPE,
            "Default" : ""
        },
        {
            "Names" : "version",
            "Description" : "The version of the secret to reference",
            "Types" : STRING_TYPE,
            "Default" : "LATEST"
        }
    ]
/]

[#function shared_dynamicvalue_aws_secret value properties sources={} ]

    [#if sources.occurrence?? ]
        [#local link = (sources.occurrence.Configuration.Solution.Links[properties.linkId])!{}]
        [#local linkTarget = getLinkTarget(sources.occurrence, link, false)]

        [#if ! linkTarget?has_content || linkTarget.Core.Type != SECRETSTORE_SECRET_COMPONENT_TYPE ]
            [@fatal
                message="Link not found or the wrong type"
                detail="link must be to a secret store secret"
                context={
                    "Component"  : sources.occurrence.Core.Component.RawId,
                    "LinkId" : properties.linkId,
                    "Links" : sources.occurrence.Configuration.Solution.Links,
                    "LinkType" : (linkTarget.Core.Type)!""
                }
            /]
            [#return ""]
        [/#if]

        [#local version = (properties.version == "LATEST")?then("", properties.version)]
        [#local secretArn = getReference(linkTarget.State.Resources.secret.Id, ARN_ATTRIBUTE_TYPE)]

        [#return {
            "Fn::Sub": [
                r'{{resolve:secretsmanager:${secretArn}:SecretString:${jsonKey}::${version}}}',
                {
                    "secretArn" : secretArn,
                    "jsonKey" : "${properties.jsonKey}",
                    "version" : "${version}"
                }
            ]
        }]
    [/#if]
    [#return "__${vaule}__"]
[/#function]
