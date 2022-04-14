[#ftl]

[#function getACMPCACertificateSubject
    commonName=""
    serialNumber=""
    country=""
    customAttributes=[]
    distinguishedNameQualifier=""
    generationQualifier=""
    givenName=""
    initials=""
    locality=""
    organization=""
    organizationUnit=""
    pseudonym=""
    state=""
    surname=""
    title=""
]

    [#return
        {} +
        attributeIfContent(
            "CommonName",
            commonName
        ) +
        attributeIfContent(
            "Country",
            country
        ) +
        attributeIfContent(
            "CustomAttributes",
            customAttributes
        ) +
        attributeIfContent(
            "DistinguishedNameQualifier",
            distinguishedNameQualifier
        ) +
        attributeIfContent(
            "GenerationQualifier",
            generationQualifier
        ) +
        attributeIfContent(
            "GivenName",
            givenName
        ) +
        attributeIfContent(
            "Initials",
            initials
        ) +
        attributeIfContent(
            "Locality",
            locality
        ) +
        attributeIfContent(
            "Organization",
            organization
        ) +
        attributeIfContent(
            "OrganizationalUnit",
            organizationUnit
        ) +
        attributeIfContent(
            "Pseudonym",
            pseudonym
        ) +
        attributeIfContent(
            "SerialNumber",
            serialNumber
        ) +
        attributeIfContent(
            "State",
            state
        ) +
        attributeIfContent(
            "Surname",
            surname
        ) +
        attributeIfContent(
            "Title",
            title
        )
    ]
[/#function]

[#assign AWS_ACMPCA_AUTHORITY_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "Attribute" : "Arn"
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_ACMPCA_AUTHORITY_RESOURCE_TYPE
    mappings=AWS_ACMPCA_AUTHORITY_OUTPUT_MAPPINGS
/]

[#macro createACMPCAAuthority id type
            keyAlgorithm
            signingAlgorithm
            subject
            revocationConfiguration={}
            csrExtensions={}
            tags=[]
            dependencies=[]]

    [@cfResource
        id=id
        type="AWS::ACMPCA::CertificateAuthority"
        properties=
            {
                "Type": type?upper_case,
                "KeyAlgorithm": keyAlgorithm,
                "SigningAlgorithm": signingAlgorithm,
                "Subject": subject
            } +
            attributeIfContent(
                "CsrExtensions",
                csrExtensions
            ) +
            attributeIfContent(
                "RevocationConfiguration",
                revocationConfiguration
            )
        tags=tags
        outputs=AWS_ACMPCA_AUTHORITY_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]

[#assign AWS_ACMPCA_CA_ACTIVATION_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        ARN_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        CERTIFICATE_ATTRIBUTE_TYPE: {
            "Attribute": "CompleteCertificateChain"
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_ACMPCA_CA_ACTIVATION_RESOURCE_TYPE
    mappings=AWS_ACMPCA_CA_ACTIVATION_OUTPUT_MAPPINGS
/]

[#macro createACMPCACAActivation id
            certificate
            certificateAuthorityId
            certificateChain=""
            status="Active"
            dependencies=[]]

    [@cfResource
        id=id
        type="AWS::ACMPCA::CertificateAuthorityActivation"
        properties=
            {
                "Certificate": certificate,
                "CertificateAuthorityArn": getArn(certificateAuthorityId),
                "Status": status?upper_case
            } +
            attributeIfContent(
                "CertificateChain",
                certificateChain
            )
        outputs=AWS_ACMPCA_CA_ACTIVATION_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]

[#macro createACMPCAPermission id
            actions
            certificateAuthorityId
            sourceAccount={"Ref": "AWS::AccountId"}
            dependencies=[]]

    [#local cleanedActions = []]
    [#list actions as action ]
        [#switch action?lower_case]
            [#case "list"]
            [#case "listpermissions"]
                [#local cleanedActions = combineEntities(
                    cleanedActions,
                    [ "ListPermissions"],
                    UNIQUE_COMBINE_BEHAVIOUR
                )]
                [#break]

            [#case "get"]
            [#case "getcertificate"]
                [#local cleanedActions = combineEntities(
                    cleanedActions,
                    [ "GetCertificate"],
                    UNIQUE_COMBINE_BEHAVIOUR
                )]
                [#break]

            [#case "issue"]
            [#case "issuecertificate"]
                [#local cleanedActions = combineEntities(
                    cleanedActions,
                    [ "IssueCertificate"],
                    UNIQUE_COMBINE_BEHAVIOUR
                )]
                [#break]

            [#default]
                [@fatal message="Invalid ACMPCA Permission action" context={ "id": id, "Action": action} /]
        [/#switch]
    [/#list]

    [@cfResource
        id=id
        type="AWS::ACMPCA::Permission"
        properties=
            {
                "Actions": cleanedActions,
                "CertificateAuthorityArn": getArn(certificateAuthorityId),
                "Principal": "acm.amazonaws.com",
                "SourceAccount" : sourceAccount
            }
        outputs={}
        dependencies=dependencies
    /]
[/#macro]

[#assign AWS_ACMPCA_CERTIFICATE_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "Attribute" : "Arn"
        },
        ARN_ATTRIBUTE_TYPE : {
            "Attribute" : "Arn"
        },
        CERTIFICATE_ATTRIBUTE_TYPE: {
            "Attribute": "Certificate"
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_ACMPCA_CERTIFICATE_RESOURCE_TYPE
    mappings=AWS_ACMPCA_CERTIFICATE_OUTPUT_MAPPINGS
/]

[#macro createACMPCACertificate id
            certificateSigningRequest
            signingAlgorithm
            validityDays
            templateArn
            certificateAuthorityId
            validityNotBeforeDate=""
            apiPassthrough={}
            dependencies=[]]

    [@cfResource
        id=id
        type="AWS::ACMPCA::Certificate"
        properties=
            {
                "CertificateAuthorityArn": getArn(certificateAuthorityId),
                "CertificateSigningRequest": certificateSigningRequest,
                "SigningAlgorithm": signingAlgorithm,
                "TemplateArn": templateArn,
                "Validity" : {
                    "Type": "DAYS",
                    "Value": validityDays
                }
            } +
            attributeIfContent(
                "ApiPassthrough",
                apiPassthrough
            ) +
            attributeIfContent(
                "ValidityNotBefore",
                validityNotBeforeDate
                {
                    "Type": "ABSOLUTE",
                    "Value": validityNotBeforeDate
                }
            )
        outputs=AWS_ACMPCA_CERTIFICATE_OUTPUT_MAPPINGS
        dependencies=dependencies
    /]
[/#macro]
