[#ftl]

[#macro aws_mta_cf_state occurrence parent={} ]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#assign componentState =
        {
            "Resources" : {},
            "Attributes" : {},
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]

    [#-- The certificate is needed to know the email domain --]
    [#if ! isPresent(solution.Certificate) ]
        [@fatal
            message="MTA Certificate must be configured to determine the email domain"
            context=occurrence
        /]
        [#return]
    [/#if]

    [#-- Get domain/host information --]
    [#local certificateObject = getCertificateObject(solution.Certificate, segmentQualifiers)]
    [#local certificateDomains = getCertificateDomains(certificateObject) ]
    [#local primaryDomainObject = getCertificatePrimaryDomain(certificateObject) ]
    [#local hostName = getHostName(certificateObject, occurrence) ]

    [#-- Direction controls state --]
    [#switch solution.Direction ]
        [#case "send" ]
            [#-- Set up sending attributes/permissions --]
            [#assign componentState +=
                {
                    "Attributes" : {
                        "REGION" : regionId,
                        "FROM" : hostName + "@" + formatDomainName(primaryDomainObject),
                        "ENDPOINT" : formatDomainName("email", regionId, "amazonaws", "com")
                    },
                    "Roles" : {
                        "Outbound" : {
                            "default" : "forward",
                            "forward" : getSESSendStatement()
                        }
                    }
                }
            ]
            [#break]

        [#case "receive" ]
            [#-- The account level SES receive configuration needs to be in the same region as the inbound mta --]
            [#assign componentState +=
                {
                    "Attributes" : {
                        "RULESET" : getExistingReference(formatSESReceiptRuleSetId(), NAME_ATTRIBUTE_TYPE, regionId),
                        "REGION" : regionId
                    }
                }
            ]
            [#break]

        [#default ]
            [@fatal
                message="Unknown MTA direction"
                detail=solution.Direction
                context=occurrence
            /]
            [#break]
    [/#switch]

[/#macro]

[#macro aws_mtarule_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local parentCore = parent.Core ]
    [#local parentSolution = parent.Configuration.Solution ]
    [#local parentState = parent.State ]

    [#assign componentState =
        {
            "Resources" : {},
            "Attributes" : {},
            "Roles" : {
                "Inbound" : {},
                "Outbound" : {}
            }
        }
    ]

    [#if parentSolution.Direction != "receive"]
        [#-- Rules only supported on a receiving MTA --]
        [#return]
    [/#if]

    [#-- As it is likely the targets of the rule links may have inbound links pointing --]
    [#-- back at the MTA, we can't use link lookups to refine the roles on a per rule  --]
    [#-- basis. So the best we can do is define all the supported link roles           --]
    [#assign componentState +=
        {
            "Resources" : {
                "rule" : {
                    "Id" : formatResourceId(AWS_SES_RECEIPT_RULE_RESOURCE_TYPE, core.Id),
                    "Name" : formatComponentFullName(core.Tier, core.Component, occurrence),
                    "Type" : AWS_SES_RECEIPT_RULE_RESOURCE_TYPE
                }
            },
            "Roles" : {
                "Inbound" : {
                    "invoke" : {
                        "Principal" : "ses.amazonaws.com",
                        "SourceAccount" : accountObject.ProviderId
                    },
                    "save" : {
                        "Principal" : "ses.amazonaws.com",
                        "Prefix" : solution["aws:Prefix"]!"",
                        "Referer" : accountObject.ProviderId
                    }
                },
                "Outbound" : {}
            }
        }
    ]

[/#macro]
