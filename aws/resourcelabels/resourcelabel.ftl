[#ftl]

[#-- Resource Labels --]
[#assign RESOURCE_LABEL_IAM     = "iam" ]
[#assign RESOURCE_LABEL_LG      = "lg" ]
[#assign RESOURCE_LABEL_EIP     = "eip" ]


[#-- Standard AWS Resource Labels --]
[@addResourceLabel
    label=RESOURCE_LABEL_IAM
    description="IAM Roles and Policies"
    levels="*"
    subsets=[ "template" ]
/]

[@addResourceLabel
    label=RESOURCE_LABEL_LG
    description="Log Group Storage and forwarding"
    levels="*"
    subsets=[ "template" ]
/]

[@addResourceLabel
    label=RESOURCE_LABEL_EIP
    description="Fixed Public IP Addresses"
    levels="*"
    subsets=[ "template" ]
/]

[#-- override iam level to include pregen for apigw --]
[@addResourceLabel
    label=RESOURCE_LABEL_IAM
    description="IAM Roles and Policies"
    levels="application"
    subsets=[ "pregeneration", "template" ]
/]

[#-- Backwards compatability support for baseline resources --]
[#assign RESOURCE_LABEL_S3      = "s3" ]
[#assign RESOURCE_LABEL_CMK     = "cmk" ]

[@addResourceLabel
    label=RESOURCE_LABEL_S3
    description="S3 resources shared across units"
    levels="segment"
    subsets=[ "template" ]
/]

[@addResourceLabel
    label=RESOURCE_LABEL_CMK
    description="KMS Keys shared across units"
    levels="segment"
    subsets=[ "template" ]
/]
