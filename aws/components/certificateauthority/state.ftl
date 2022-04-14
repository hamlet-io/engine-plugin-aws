[#ftl]

[#macro aws_certificateauthority_cf_state occurrence parent={} ]
    [#local core = getOccurrenceCore(occurrence) ]
    [#local solution = getOccurrenceSolution(occurrence) ]

    [#local authorityId = formatResourceId(AWS_ACMPCA_AUTHORITY_RESOURCE_TYPE, occurrence.Core.Id)]
    [#local rootCertificateId = formatResourceId(AWS_ACMPCA_CERTIFICATE_RESOURCE_TYPE, occurrence.Core.Id)]

    [#assign componentState =
        {
            "Resources" : {
                "authority" : {
                    "Id" : authorityId,
                    "Name": occurrence.Core.RawFullName,
                    "SerialNumber": getSegmentSeed(),
                    "Type" : AWS_ACMPCA_AUTHORITY_RESOURCE_TYPE
                },
                "activation" : {
                    "Id" : formatResourceId(AWS_ACMPCA_CA_ACTIVATION_RESOURCE_TYPE, occurrence.Core.Id),
                    "Type" : AWS_ACMPCA_CA_ACTIVATION_RESOURCE_TYPE
                },
                "certificate" : {
                    "Id" : rootCertificateId,
                    "Type" : AWS_ACMPCA_CERTIFICATE_RESOURCE_TYPE
                },
                "authorityPermission" : {
                    "Id" : formatResourceId(AWS_ACMPCA_PERMISSION_RESOURCE_TYPE, occurrence.Core.Id),
                    "Type" : AWS_ACMPCA_PERMISSION_RESOURCE_TYPE
                }
            },
            "Attributes" : {
                "ARN" : getExistingReference(authorityId),
                "CERTIFICATE_CHAIN": getExistingReference(rootCertificateId, CERTIFICATE_ATTRIBUTE_TYPE)
            },
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]
[/#macro]
