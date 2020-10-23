[#ftl]

[#-- Service Mapping --]
[@addDiagramServiceMapping
    provider=AWS_PROVIDER
    service=AWS_IDENTITY_SERVICE
    diagramsClass="diagrams.aws.security.IdentityAndAccessManagementIam"
/]

[@addDiagramResourceMapping
    provider=AWS_PROVIDER
    service=AWS_IDENTITY_SERVICE
    resourceType=AWS_IAM_ROLE_RESOURCE_TYPE
    diagramsClass="diagrams.aws.security.IdentityAndAccessManagementIamRole"
/]

[@addDiagramResourceMapping
    provider=AWS_PROVIDER
    service=AWS_IDENTITY_SERVICE
    resourceType=AWS_IAM_POLICY_RESOURCE_TYPE
    diagramsClass="diagrams.aws.security.IdentityAndAccessManagementIamPermissions"
/]
