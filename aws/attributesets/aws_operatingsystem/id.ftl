[#ftl]

[@addExtendedAttributeSet
    type=AWS_OPERATINGSYSTEM_ATTRIBUTESET_TYPE
    baseType=OPERATINGSYSTEM_ATTRIBUTESET_TYPE
    provider=AWS_PROVIDER
    properties=[
        {
                "Type"  : "Description",
                "Value" : "Standard Configuration options to define an operating system"
        }]
    attributes=[
        {
            "Names" : "Family",
            "Default" : "linux"
        },
        {
            "Names" : "Distribution",
            "Default": "awslinux"
        },
        {
            "Names" : "MajorVersion",
            "Default" : "1"
        }
    ]
/]
