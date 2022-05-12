[#ftl]

[#-- Resources --]
[#assign AWS_CERTIFICATE_RESOURCE_TYPE="certificate" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_CERTIFICATE_MANAGER_SERVICE
    resource=AWS_CERTIFICATE_RESOURCE_TYPE
/]

[#function formatCertificateId ids...]
    [#return formatResourceId(
                AWS_CERTIFICATE_RESOURCE_TYPE,
                ids)]
[/#function]

[#function formatDependentCertificateId resourceId extensions...]
    [#return formatDependentResourceId(
                AWS_CERTIFICATE_RESOURCE_TYPE,
                resourceId,
                extensions)]
[/#function]

[#function formatComponentCertificateId tier component extensions...]
    [#return formatComponentResourceId(
                AWS_CERTIFICATE_RESOURCE_TYPE,
                tier,
                component,
                extensions)]
[/#function]

[#function formatDomainCertificateId certificateObject, hostName=""]
    [#local primaryDomain = getCertificatePrimaryDomain(certificateObject) ]
    [#if primaryDomain.Name?has_content ]
        [#if !primaryDomain.Name?contains(".") ]
            [@fatal message="Missing domain name for ACM primary domain" context=solution /]
            [#return ""]
        [/#if]
        [#return
            formatResourceId(
                AWS_CERTIFICATE_RESOURCE_TYPE,
                certificateObject.Wildcard?then(
                    "star",
                    hostName
                ),
                splitDomainName(primaryDomain.Name)
            ) ]
    [/#if]

    [#return ""]
[/#function]
