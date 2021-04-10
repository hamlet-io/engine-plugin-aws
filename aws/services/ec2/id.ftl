[#ftl]

[#-- Parameter Type --]
[#assign AWS_EC2_AMI_PARAMETER_TYPE = "amiParam"]

[#-- Resources --]
[#assign AWS_EC2_INSTANCE_RESOURCE_TYPE = "ec2Instance" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_COMPUTE_SERVICE
    resource=AWS_EC2_INSTANCE_RESOURCE_TYPE
/]

[#assign AWS_EC2_INSTANCE_PROFILE_RESOURCE_TYPE = "instanceProfile" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_COMPUTE_SERVICE
    resource=AWS_EC2_INSTANCE_PROFILE_RESOURCE_TYPE
/]
[#assign AWS_EC2_AUTO_SCALE_GROUP_RESOURCE_TYPE = "asg" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_COMPUTE_SERVICE
    resource=AWS_EC2_AUTO_SCALE_GROUP_RESOURCE_TYPE
/]

[#assign AWS_EC2_LAUNCH_CONFIG_RESOURCE_TYPE = "launchConfig" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_COMPUTE_SERVICE
    resource=AWS_EC2_LAUNCH_CONFIG_RESOURCE_TYPE
/]
[#assign AWS_EC2_NETWORK_INTERFACE_RESOURCE_TYPE = "eni" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_COMPUTE_SERVICE
    resource=AWS_EC2_NETWORK_INTERFACE_RESOURCE_TYPE
/]
[#assign AWS_EC2_KEYPAIR_RESOURCE_TYPE = "keypair" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_COMPUTE_SERVICE
    resource=AWS_EC2_KEYPAIR_RESOURCE_TYPE
/]

[#assign AWS_EC2_EBS_RESOURCE_TYPE = "ebs" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_COMPUTE_SERVICE
    resource=AWS_EC2_EBS_RESOURCE_TYPE
/]

[#assign AWS_EC2_EBS_ATTACHMENT_RESOURCE_TYPE = "ebsAttachment" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_COMPUTE_SERVICE
    resource=AWS_EC2_EBS_ATTACHMENT_RESOURCE_TYPE
/]

[#assign AWS_EC2_EBS_MANUAL_SNAPSHOT_RESOURCE_TYPE = "manualsnapshot" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_COMPUTE_SERVICE
    resource=AWS_EC2_EBS_MANUAL_SNAPSHOT_RESOURCE_TYPE
/]


[#assign AWS_EIP_RESOURCE_TYPE = "eip" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_COMPUTE_SERVICE
    resource=AWS_EIP_RESOURCE_TYPE
/]

[#assign AWS_EIP_ASSOCIATION_RESOURCE_TYPE = "eipAssoc" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_COMPUTE_SERVICE
    resource=AWS_EIP_ASSOCIATION_RESOURCE_TYPE
/]

[#assign AWS_SSH_KEY_PAIR_RESOURCE_TYPE = "sshKeyPair" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_COMPUTE_SERVICE
    resource=AWS_SSH_KEY_PAIR_RESOURCE_TYPE
/]

[#function formatEC2InstanceId tier component extensions...]
    [#return formatComponentResourceId(
                AWS_EC2_INSTANCE_RESOURCE_TYPE,
                tier,
                component,
                extensions)]
[/#function]

[#function formatEC2InstanceProfileId tier component extensions...]
    [#return formatComponentResourceId(
                AWS_EC2_INSTANCE_PROFILE_RESOURCE_TYPE,
                tier,
                component,
                extensions)]
[/#function]

[#function formatEC2AutoScaleGroupId tier component extensions...]
    [#return formatComponentResourceId(
                AWS_EC2_AUTO_SCALE_GROUP_RESOURCE_TYPE,
                tier,
                component,
                extensions)]
[/#function]

[#function formatEC2LaunchConfigId tier component extensions...]
    [#return formatComponentResourceId(
                AWS_EC2_LAUNCH_CONFIG_RESOURCE_TYPE,
                tier,
                component,
                extensions)]
[/#function]

[#function formatEC2ENIId tier component extensions...]
    [#return formatComponentResourceId(
                AWS_EC2_NETWORK_INTERFACE_RESOURCE_TYPE,
                tier,
                component,
                extensions)]
[/#function]

[#function formatEC2SecurityGroupId tier component]
    [#return formatComponentSecurityGroupId(
                        tier,
                        component)]
[/#function]

[#function formatEC2RoleId tier component]
    [#-- TODO: Use formatDependentRoleId() --]
    [#return formatComponentRoleId(
                tier,
                component)]
[/#function]

[#function formatEC2SecurityGroupIngressId tier component port]
    [#return formatComponentSecurityGroupIngressId(
                tier,
                component,
                port.Port?c)]
[/#function]

[#function formatEC2KeyPairId extensions...]
    [#return formatSegmentResourceId(
                AWS_EC2_KEYPAIR_RESOURCE_TYPE,
                extensions)]
[/#function]

[#function formatEIPId ids...]
    [#return formatResourceId(
                AWS_EIP_RESOURCE_TYPE,
                ids)]
[/#function]

[#function formatEIPAssociationId ids...]
    [#return formatResourceId(
        AWS_EIP_ASSOCIATION_RESOURCE_TYPE,
        ids)]
[/#function]

[#function formatDependentEIPId resourceId extensions...]
    [#return formatEIPId(
                resourceId,
                extensions)]
[/#function]

[#function formatComponentEIPId tier component extensions...]
    [#return formatComponentResourceId(
                AWS_EIP_RESOURCE_TYPE,
                tier,
                component,
                extensions)]
[/#function]

[#function formatComponentEIPAssociationId tier component extensions...]
    [#return formatComponentResourceId(
                AWS_EIP_ASSOCIATION_RESOURCE_TYPE,
                tier,
                component,
                extensions)]
[/#function]


[#function formatEC2AccountVolumeEncryptionId ]
    [#return formatAccountResourceId("volumeencrypt")]
[/#function]

[#function formatEc2AccountVolumeEncryptionKMSKeyId ]
    [#return formatAccountResourceId(AWS_CMK_RESOURCE_TYPE, "volumeencrypt" ) ]
[/#function]
