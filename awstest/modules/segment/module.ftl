[#ftl]

[@addModule
    name="segment"
    description="Fixture to provide the base level segment units for other components"
    provider=AWSTEST_PROVIDER
    properties=[]
/]

[#macro awstest_module_segment ]

    [@loadModule
        stackOutputs=[
            {
                "Account" : "0123456789",
                "Region" : "mock-region-1",
                "DeploymentUnit" : "baseline",

                "seedXsegment": "568132487",

                "s3XsegmentXappdata": "segment-baseline-appdata",
                "s3XsegmentXappdataXname": "segment-baseline-appdata",
                "s3XsegmentXappdataXarn": "arn:aws:s3:::segment-baseline-appdata",
                "s3XsegmentXappdataXurl": "http://segment-baseline-appdata.s3-website-mock-region-1.amazonaws.com",
                "s3XsegmentXappdataXdns": "segment-baseline-appdata.s3.amazonaws.com",
                "s3XsegmentXappdataXregion": "mock-region-1",

                "s3XsegmentXopsdata": "segment-baseline-opsdata",
                "s3XsegmentXopsdataXname": "segment-baseline-opsdata",
                "s3XsegmentXopsdataXarn": "arn:aws:s3:::segment-baseline-opsdata",
                "s3XsegmentXopsdataXurl": "http://segment-baseline-opsdata.s3-website-mock-region-1.amazonaws.com",
                "s3XsegmentXopsdataXdns": "segment-baseline-opsdata.s3.amazonaws.com",
                "s3XsegmentXopsdataXregion": "mock-region-1",

                "cfaccessXmgmtXbaselineXoai": "ABC123ABC123AB",
                "cfaccessXmgmtXbaselineXoaiXcanonicalid": "111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111",

                "cmkXmgmtXbaselineXcmk": "123abc1e-1a2b-1a2b-1a2b-123456789ABC",
                "cmkXmgmtXbaselineXcmkXarn": "arn:aws:kms:mock-region-1:0123456789:key/123abc1e-1a2b-1a2b-1a2b-123456789ABC",

                "sshKeyPairXmgmtXbaselineXssh": "mockedup-integration-management-baseline-ssh",
                "sshKeyPairXmgmtXbaselineXsshXname": "mockedup-integration-management-baseline-ssh"
            },
            {
                "Account" : "0123456789",
                "Region" : "mock-region-1",
                "DeploymentUnit" : "vpc",

                "vpcXmgmtXvpc": "vpc-123456789abcdef12",
                "vpcXmgmtXvpcXregion": "mock-region-1",

                "routeTableXmgmtXvpcXinternalXa": "rtb-123456789abcdef11",
                "routeTableXmgmtXvpcXinternalXb": "rtb-21fedcba987654321",

                "routeTableXmgmtXvpcXexternalXa": "rtb-123456789abcdef12",
                "routeTableXmgmtXvpcXexternalXb": "rtb-21fedcba987654322",

                "subnetListXmgmtXvpcXweb": "subnet-123456789abcdef11,subnet-21fedcba987654321",
                "subnetXmgmtXvpcXwebXa": "subnet-123456789abcdef11",
                "subnetXmgmtXvpcXwebXb": "subnet-21fedcba987654321",

                "subnetListXmgmtXvpcXmsg": "subnet-123456789abcdef12,subnet-21fedcba987654322",
                "subnetXmgmtXvpcXmsgXa": "subnet-123456789abcdef12",
                "subnetXmgmtXvpcXmsgXb": "subnet-21fedcba987654322",

                "subnetListXmgmtXvpcXapp": "subnet-123456789abcdef13,subnet-21fedcba987654323",
                "subnetXmgmtXvpcXappXa": "subnet-123456789abcdef13",
                "subnetXmgmtXvpcXappXb": "subnet-21fedcba987654323",

                "subnetListXmgmtXvpcXdb": "subnet-123456789abcdef14,subnet-21fedcba987654324",
                "subnetXmgmtXvpcXdbXa": "subnet-123456789abcdef14",
                "subnetXmgmtXvpcXdbXb": "subnet-21fedcba987654324",

                "subnetListXmgmtXvpcXdir": "subnet-123456789abcdef15,subnet-21fedcba987654325",
                "subnetXmgmtXvpcXdirXa": "subnet-123456789abcdef15",
                "subnetXmgmtXvpcXdirXb": "subnet-21fedcba987654325",

                "subnetListXmgmtXvpcXana": "subnet-123456789abcdef16,subnet-21fedcba987654326",
                "subnetXmgmtXvpcXanaXa": "subnet-123456789abcdef16",
                "subnetXmgmtXvpcXanaXb": "subnet-21fedcba987654326",

                "subnetListXmgmtXvpcXapi": "subnet-123456789abcdef17,subnet-21fedcba987654327",
                "subnetXmgmtXvpcXapiXa": "subnet-123456789abcdef17",
                "subnetXmgmtXvpcXapiXb": "subnet-21fedcba987654327",

                "subnetListXmgmtXvpcXelb": "subnet-123456789abcdef18,subnet-21fedcba987654328",
                "subnetXmgmtXvpcXelbXa": "subnet-123456789abcdef18",
                "subnetXmgmtXvpcXelbXb": "subnet-21fedcba987654328",

                "subnetListXmgmtXvpcXilb": "subnet-123456789abcdef18,subnet-21fedcba987654328",
                "subnetXmgmtXvpcXilbXa": "subnet-123456789abcdef18",
                "subnetXmgmtXvpcXilbXb": "subnet-21fedcba987654328",

                "subnetListXmgmtXvpcXmgmt": "subnet-123456789abcdef19,subnet-21fedcba987654329",
                "subnetXmgmtXvpcXmgmtXa": "subnet-123456789abcdef19",
                "subnetXmgmtXvpcXmgmtXb": "subnet-21fedcba987654329"
            },
            {
                "Account" : "0123456789",
                "Region" : "mock-region-1",
                "DeploymentUnit" : "ssh",

                "securityGroupXmgmtXssh": "sg-00990099009900999"
            },
            {
                "Account" : "0123456789",
                "Region" : "mock-region-1",
                "DeploymentUnit" : "cert",

                "certificateXstarXmockXlocal": "arn:aws:acm:mock-region-1:0123456789:certificate/12345678-abab-abab-abab-1234567890ab",
                "certificateXstarXmockXlocalXarn": "arn:aws:acm:mock-region-1:0123456789:certificate/12345678-abab-abab-abab-1234567890ab"
            },
            {
                "Account" : "0123456789",
                "Region" : "us-east-1",
                "DeploymentUnit" : "cert",

                "certificateXstarXmockXlocal": "arn:aws:acm:us-east-1:0123456789:certificate/12345678-abab-abab-abab-1234567890ab",
                "certificateXstarXmockXlocalXarn": "arn:aws:acm:us-east-1:0123456789:certificate/12345678-abab-abab-abab-1234567890ab"
            }
        ]
    /]
[/#macro]
