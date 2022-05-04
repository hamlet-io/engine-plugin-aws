[#ftl]

[@addTask
    type=AWS_SES_SMTP_PASSWORD_TASK_TYPE
    properties=[
            {
                "Type"  : "Description",
                "Value" : "Generate a Sig4 based SMTP credential that is used to authenciate with ses via SMTP"
            }
        ]
    attributes=[
        {
            "Names" : "SESRegion",
            "Description" : "The name of the region that the SMTP endpoint will be used",
            "Types" : STRING_TYPE,
            "Mandatory" : true
        },
        {
            "Names" : "AWSSecretAccessKey",
            "Description" : "The secret key of the access key pair that will be used to send emails via SMTP",
            "Types" : STRING_TYPE,
            "Mandatory" : true
        }
    ]
/]
