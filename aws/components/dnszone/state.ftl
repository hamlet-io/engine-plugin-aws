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

    [#local attributes = {}]
    [#local resources = {}]

    [#if solution["external:ProviderId"]?? ]

        [#-- Combine any placement attributes with explicitly provided values --]
        [#local attributes =
            {
                "REGION" : "us-east-1"
            } +
            ((locations[DEFAULT_RESOURCE_GROUP].Attributes)!{}) +
            attributeIfContent(
                "ZONE",
                solution["external:ProviderId"]!""
            )
        ]

        [#local resources = {
            "external" : {
                "Id" : formatResourceId(AWS_ROUTE53_HOSTED_ZONE_RESOURCE_TYPE, core.Id),
                "Type" : AWS_ROUTE53_HOSTED_ZONE_RESOURCE_TYPE,
                "Deployed" :
                    attributes["PROVIDER"]?has_content &&
                    attributes["ACCOUNT"]?has_content &&
                    attributes["ZONE"]?has_content
            }
        }]
    [#else]
        [#local resources = {
            "zone" : {
                "Id": zoneId,
                "Name" : domainName,
                "Type": AWS_ROUTE53_HOSTED_ZONE_RESOURCE_TYPE
            }
        }]

        [#local attributes = {
            "DOMAIN" : domainName,
            "ZONE" : getExistingReference(zoneId)
        }]
    [/#if]

    [#assign componentState =
        {
            "Resources": resources,
            "Attributes": attributes,
            "Roles": {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]
[/#macro]
