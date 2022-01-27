[#ftl]

[#-- Resources --]
[#assign AWS_BACKUP_VAULT_RESOURCE_TYPE = "backupvault" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_BACKUP_SERVICE
    resource=AWS_BACKUP_VAULT_RESOURCE_TYPE
/]
[#assign AWS_BACKUP_PLAN_RESOURCE_TYPE = "backupplan" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_BACKUP_SERVICE
    resource=AWS_BACKUP_PLAN_RESOURCE_TYPE
/]
[#assign AWS_BACKUP_SELECTION_RESOURCE_TYPE = "backupselection" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_BACKUP_SERVICE
    resource=AWS_BACKUP_SELECTION_RESOURCE_TYPE
/]

