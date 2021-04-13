[#ftl]

[@addExtendedAttributeSet
    type=AWS_ECS_COMPUTEIMAGE_ATTRIBUTESET_TYPE
    baseType=AWS_COMPUTEIMAGE_ATTRIBUTESET_TYPE
    pluralType="AWSECSComputeImages"
    provider=AWS_PROVIDER
    properties=[
        {
                "Type"  : "Description",
                "Value" : "AWS ECS Specific overrides to source compute images"
        }]
    attributes=[
        {
            "Names" : "Source:Reference",
            "Children" : [
                {
                    "Names" : "OS",
                    "Default" : "Centos"
                },
                {
                    "Names" : "Type",
                    "Default" : "ECS"
                }
            ]
        },
        {
            "Names" : "Source:SSMParam",
            "Children" : [
                {
                    "Names" : "Name",
                    "Default" : "/aws/service/ecs/optimized-ami/amazon-linux/recommended/image_id"
                }
            ]
        }
    ]
/]
