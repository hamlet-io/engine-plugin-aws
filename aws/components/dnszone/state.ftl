[#ftl]

[#macro aws_dnszone_cf_state occurrence parent={} ]
    [#local core = getOccurrenceCore(occurrence) ]
    [#local solution = getOccurrenceSolution(occurrence) ]
    [#local locations = getOccurrenceLocations(occurrence) ]

    [#local domainObject = getCertificateObject(
        {} +
        attributeIfContent(
            "Domain",
            (solution.Domain)!""
        ) +
        attributeIfTrue(
            "IncludeInDomain",
            solution.IncludeInDomain.Configured
        )
    )]

    [#local domainName = getCertificatePrimaryDomain(domainObject).Name ]
    [#local zoneId = formatResourceId(AWS_ROUTE53_HOSTED_ZONE_RESOURCE_TYPE, core.Id) ]

    [#assign componentState =
        {
            "Resources": {
                "zone" : {
                    "Id": zoneId,
                    "Name" : domainName,
                    "Type": AWS_ROUTE53_HOSTED_ZONE_RESOURCE_TYPE
                }
            },
            "Attributes": {
                "DOMAIN" : domainName,
                "ZONE" : getExistingReference(zoneId)
            },
            "Roles": {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]
[/#macro]
