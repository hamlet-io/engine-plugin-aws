[#ftl]

[#-- Resources --]
[#assign AWS_ACMPCA_AUTHORITY_RESOURCE_TYPE = "ACMPCAAuthority" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_CERTIFICATE_MANAGER_PRIVATE_CA_SERVICE
    resource=AWS_ACMPCA_AUTHORITY_RESOURCE_TYPE
/]

[#assign AWS_ACMPCA_CA_ACTIVATION_RESOURCE_TYPE = "ACMPCActivation" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_CERTIFICATE_MANAGER_PRIVATE_CA_SERVICE
    resource=AWS_ACMPCA_CA_ACTIVATION_RESOURCE_TYPE
/]

[#assign AWS_ACMPCA_CERTIFICATE_RESOURCE_TYPE = "ACMPCACertificate" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_CERTIFICATE_MANAGER_PRIVATE_CA_SERVICE
    resource=AWS_ACMPCA_CERTIFICATE_RESOURCE_TYPE
/]

[#assign AWS_ACMPCA_PERMISSION_RESOURCE_TYPE = "ACMPCAPermission" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_CERTIFICATE_MANAGER_PRIVATE_CA_SERVICE
    resource=AWS_ACMPCA_PERMISSION_RESOURCE_TYPE
/]
