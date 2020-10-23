[#ftl]

[#-- Resources --]
[#assign AWS_COGNITO_USERPOOL_RESOURCE_TYPE = "userpool"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_COGNITO_SERVICE
    resource=AWS_COGNITO_USERPOOL_RESOURCE_TYPE
/]
[#assign AWS_COGNITO_USERPOOL_CLIENT_RESOURCE_TYPE = "userpoolclient"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_COGNITO_SERVICE
    resource=AWS_COGNITO_USERPOOL_CLIENT_RESOURCE_TYPE
/]
[#assign AWS_COGNITO_IDENTITYPOOL_RESOURCE_TYPE = "identitypool"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_COGNITO_SERVICE
    resource=AWS_COGNITO_IDENTITYPOOL_RESOURCE_TYPE
/]
[#assign AWS_COGNITO_IDENTITYPOOL_ROLEMAPPING_RESOURCE_TYPE = "rolemapping"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_COGNITO_SERVICE
    resource=AWS_COGNITO_IDENTITYPOOL_ROLEMAPPING_RESOURCE_TYPE
/]
[#assign AWS_COGNITO_USERPOOL_DOMAIN_RESOURCE_TYPE = "userpooldomain" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_COGNITO_SERVICE
    resource=AWS_COGNITO_USERPOOL_DOMAIN_RESOURCE_TYPE
/]
[#assign AWS_COGNITO_USERPOOL_AUTHPROVIDER_RESOURCE_TYPE = "userpoolauthprovider" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_COGNITO_SERVICE
    resource=AWS_COGNITO_USERPOOL_AUTHPROVIDER_RESOURCE_TYPE
/]
[#assign AWS_COGNITO_USERPOOL_RESOURCESERVER_RESOURCE_TYPE = "userpoolresourceserver"]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_COGNITO_SERVICE
    resource=AWS_COGNITO_USERPOOL_RESOURCESERVER_RESOURCE_TYPE
/]
[#assign AWS_COGNITO_USERPOOL_RESOURCESCOPE_RESOURCE_TYPE = "userpoolresourcescope" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_COGNITO_SERVICE
    resource=AWS_COGNITO_USERPOOL_RESOURCESCOPE_RESOURCE_TYPE
/]
