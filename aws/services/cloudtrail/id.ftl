[#ftl]

[#assign AWS_CLOUDTRAIL_TRAIL_RESOURCE_TYPE = "cloudtrailTrail"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_CLOUDTRAIL_SERVICE
    resource=AWS_CLOUDTRAIL_TRAIL_RESOURCE_TYPE
/]


[#function getAccountCloudTrailProviderAuditingName]
    [#return
        formatName(
                "providerauditing",
                accountObject.ProviderAuditing.Scope,
                (accountObject.ProviderAuditing.Scope == "Account")?then(
                    accountObject.ProviderId,
                    ((tenantObject.Name)!tenantObject.Id)
                )
            )
    ]
[/#function]

[#function getAccountCloudTrailProviderAuditingS3Prefix ]
    [#local objectStore = (accountObject.ProviderAuditing.StorageLocations?values?filter(
        x -> x.Type == "Object"
    )?first)]

    [#if objectStore?has_content ]
        [#return (objectStore["Type:Object"].Prefix == "_provider")?then(
            "",
            storageLocation["Type:Object"].Prefix
        )]
    [/#if]
    [#return ""]
[/#function]
