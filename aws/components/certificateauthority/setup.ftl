[#ftl]
[#macro aws_certificateauthority_cf_deployment_generationcontract occurrence ]
    [@addDefaultGenerationContract subsets=["template" ] /]
[/#macro]

[#macro aws_certificateauthority_cf_deployment_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core ]
    [#local resources = occurrence.State.Resources]
    [#local solution = occurrence.Configuration.Solution ]

    [#local authorityId = resources["authority"].Id ]
    [#local authorityName = resources["authority"].Name ]
    [#local authoritySerialNumber = resources["authority"].SerialNumber ]

    [#local certificateId = resources["certificate"].Id]

    [#local certificateObject = getCertificateObject(solution.Subject.CommonName) ]
    [#local commonName = getHostName(certificateObject, occurrence) ]

    [#local certificateSubject = getACMPCACertificateSubject(
        commonName, authoritySerialNumber
    )]

    [#if deploymentSubsetRequired(CERTIFICATEAUTHORITY_COMPONENT_TYPE, true)]

        [#switch (solution.Level)?lower_case ]
            [#case "root"]
                [#local activationAuthorityId = authorityId]
                [#local activationCertificateChain = ""]
                [#local certificateTemplateArn = "arn:aws:acm-pca:::template/RootCACertificate/V1"]
                [#break]

            [#case "subordinate"]

                [#local parentAuthorityLink = getLinkTarget(occurrence, solution["level:Subordinate"].ParentAuthority.Link, true, true)]

                [#local activationAuthorityId = (parentAuthorityLink.State.Attributes.ARN)!"" ]
                [#local activationCertificateChain = (parentAuthorityLink.State.Attributes.CERTIFICATE_CHAIN)!"" ]
                [#local certificateTemplateArn = "arn:aws:acm-pca:::template/SubordinateCACertificate_PathLen${solution['level:Subordinate'].MaxLevels}/V1" ]
                [#break]
        [/#switch]

        [@createACMPCAAuthority
            id=authorityId
            type=solution.Level
            keyAlgorithm=solution.KeyAlgorithm
            signingAlgorithm=solution.SigningAlgorithm
            subject=certificateSubject
            tags=getOccurrenceCoreTags(occurrence, authorityName)
        /]

        [@createACMPCACertificate
            id=certificateId
            certificateSigningRequest={
                "Fn::GetAtt" : [
                    authorityId,
                    "CertificateSigningRequest"
                ]
            }
            signingAlgorithm=solution.SigningAlgorithm
            validityDays=solution.Validity.Length
            templateArn=certificateTemplateArn
            certificateAuthorityId=activationAuthorityId
        /]

        [@createACMPCACAActivation
            id=resources["activation"].Id
            certificate=getReference(certificateId, CERTIFICATE_ATTRIBUTE_TYPE)
            certificateAuthorityId=activationAuthorityId
            certificateChain=activationCertificateChain
        /]

        [@createACMPCAPermission
            id=resources["authorityPermission"].Id
            actions=[
                "issue",
                "get",
                "list"
            ]
            certificateAuthorityId=authorityId
        /]

    [/#if]
[/#macro]
