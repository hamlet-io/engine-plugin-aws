[#ftl]

[#macro aws_mta_cf_state occurrence parent={} ]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#assign componentState =
        {
            "Resources" : {},
            "Attributes" : {},
            "Roles" : {
                 "Inbound" : {
                    "invoke" : {
                        "Principal" : "ses.amazonaws.com",
                        "SourceAccount" : { "Ref" : "AWS::AccountId" }
                    }
                },
                "Outbound" : {}
            }
        }
    ]

    [#-- The certificate is needed to know the email domain --]
    [#if ! isPresent(solution.Hostname) ]
        [@fatal
            message="MTA Certificate must be configured to determine the email domain"
            context=occurrence
        /]
        [#return]
    [/#if]

    [#-- Get domain/host information --]
    [#local certificateObject = getCertificateObject(solution.Hostname)]
    [#local certificateDomains = getCertificateDomains(certificateObject) ]
    [#local primaryDomainObject = getCertificatePrimaryDomain(certificateObject) ]
    [#local hostName = getHostName(certificateObject, occurrence) ]

    [#-- Direction controls state --]
    [#switch solution.Direction ]
        [#case "send" ]
            [#-- Set up sending attributes/permissions --]
            [#assign componentState = mergeObjects(
                componentState,
                {
                    "Attributes" : {
                        "REGION" : getRegion(),
                        "MAIL_DOMAIN" : formatDomainName(primaryDomainObject),
                        "FROM" : hostName + "@" + formatDomainName(primaryDomainObject),
                        "ENDPOINT" : formatDomainName("email", getRegion(), "amazonaws", "com"),
                        "SMTP_ENDPOINT" : formatDomainName("email-smtp", getRegion(), "amazonaws", "com")
                    },
                    "Roles" : {
                        "Outbound" : {
                            "default" : "forward",
                            "forward" : getSESSendStatement()
                        }
                    }
                }
            )]
            [#break]

        [#case "receive" ]
            [#-- The account level SES receive configuration needs to be in the same region as the inbound mta --]
            [#assign componentState = mergeObjects(
                componentState,
                {
                    "Attributes" : {
                        "RULESET" : getExistingReference(formatSESReceiptRuleSetId(), NAME_ATTRIBUTE_TYPE, getRegion()),
                        "REGION" : getRegion()
                    }
                }
            )]
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

    [#switch parentSolution.Direction]
        [#case "receive"]
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
        [#break]

        [#case "send"]

            [#local configSetDestinations = {}]

            [#list occurrence.Configuration.Solution.Links as linkId,link ]
                [#local configSetDestinations = mergeObjects(
                    configSetDestinations,
                    {
                        linkId : {
                            "Id": formatResourceId(AWS_SES_CONFIGSET_DEST_RESOURCE_TYPE, occurrence.Core.Id, linkId),
                            "Name": formatName(occurrence.Core.RawFullName, linkId),
                            "Type" : AWS_SES_CONFIGSET_DEST_RESOURCE_TYPE
                        }
                    }
                )]
            [/#list]

            [#assign componentState +=
                {
                    "Resources" : {
                        "configset" : {
                            "Id" : formatResourceId(AWS_SES_CONFIGSET_RESOURCE_TYPE, core.Id),
                            "Name" : occurrence.Core.FullName,
                            "Type" : AWS_SES_CONFIGSET_RESOURCE_TYPE
                        },
                        "configSetDestinations" : configSetDestinations
                    }
                }
            ]
        [#break]
    [/#switch]
[/#macro]
