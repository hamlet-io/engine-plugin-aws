[#ftl]

[@addTask
    type=AWS_RDS_CREATE_SNAPSHOT_TASK_TYPE
    properties=[
            {
                "Type"  : "Description",
                "Value" : "Create an rds native snapshot for either an instance or cluster, wait for it to become available and then return the arn"
            }
        ]
    attributes=[
        {
            "Names" : "DbId",
            "Description" : "The Arn or Id of the rds instance or cluster",
            "Types" : STRING_TYPE,
            "Mandatory" : true
        },
        {
            "Names": "Cluster",
            "Description" : "If the database is a cluster or instance",
            "Types" : [ STRING_TYPE, BOOLEAN_TYPE ],
            "Mandatory" : true
        },
        {
            "Names": "SnapshotName",
            "Description" : "The name of the snapshot",
            "Types" : STRING_TYPE,
            "Mandatory" : true
        },
        {
            "Names" : "IncludeDateSuffix",
            "Description" : "Include a date based suffix in the snapshot name",
            "Types" : [ STRING_TYPE, BOOLEAN_TYPE ],
            "Default" : true
        },
        {
            "Names" : "Region",
            "Description" : "The name of the region to use for the aws session",
            "Types" : STRING_TYPE
        }
        {
            "Names" : "AWSAccessKeyId",
            "Description" : "The AWS Access Key Id with access to decrypt",
            "Types" : STRING_TYPE
        },
        {
            "Names" : "AWSSecretAccessKey",
            "Description" : "The AWS Secret Access Key with access to decrypt",
            "Types" : STRING_TYPE
        },
        {
            "Names" : "AWSSessionToken",
            "Description" : "The AWS Session Token with access to decrypt",
            "Types" : STRING_TYPE
        }
    ]
/]
