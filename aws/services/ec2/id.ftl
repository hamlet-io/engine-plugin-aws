[#ftl]

[#-- ComputeTask config Engines --]
[#assign AWS_EC2_USERDATA_COMPUTE_TASK_CONFIG_TYPE = "userdata"]
[#assign AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE = "cfninit" ]
[#assign AWS_EC2_CFN_INIT_WAIT_COMPUTE_TASK_CONFIG_TYPE = "cfninitwait"]

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

[#function formatEC2KeyPairId extensions...]
    [#return formatSegmentResourceId(
                AWS_EC2_KEYPAIR_RESOURCE_TYPE,
                extensions)]
[/#function]

[#function formatEC2AccountVolumeEncryptionId ]
    [#return formatAccountResourceId("volumeencrypt")]
[/#function]

[#function formatEc2AccountVolumeEncryptionKMSKeyId ]
    [#return formatAccountResourceId(AWS_CMK_RESOURCE_TYPE, "volumeencrypt" ) ]
[/#function]
