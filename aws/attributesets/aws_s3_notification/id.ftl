[#ftl]

[@addExtendedAttributeSet
    type=AWS_S3_NOTIFICATION_ATTRIBUTESET_TYPE
    baseType=OBJECTSTORE_NOTIFICATION_ATTRIBUTESET_TYPE
    provider=AWS_PROVIDER
    properties=[
        {
                "Type"  : "Description",
                "Value" : "AWS S3 specific configuration options for notifications"
        }]
    attributes=[
        {
            "Names" : "QueuePermissionMigration",
            "Description" : "Deprecation alert: set to true once policy updated for queue",
            "Types" : BOOLEAN_TYPE,
            "Default" : false
        },
        {
            "Names" : "TopicPermissionMigration",
            "Description" : "Deprecation alert: set to true once policy updated for topic",
            "Types" : BOOLEAN_TYPE,
            "Default" : false
        }

    ]
/]
