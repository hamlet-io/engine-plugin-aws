[#ftl]

[@addExtendedAttributeSet
    type=AWS_COMPUTEIMAGE_ATTRIBUTESET_TYPE
    baseType=COMPUTEIMAGE_ATTRIBUTESET_TYPE
    pluralType="AWSComputeImages"
    provider=AWS_PROVIDER
    properties=[
        {
                "Type"  : "Description",
                "Value" : "AWS Specific overrides to source compute images"
        }]
    attributes=[
        {
            "Names" : "Source",
            "Values" : [ "AMI", "SSMParam" ]
        },
        {
            "Names" : "Source:AMI",
            "Description" : "Use an explicit AMI for the image ",
            "Children" : [
                {
                    "Names" : "ImageId",
                    "Types" : STRING_TYPE
                }
            ]
        },
        {
            "Names" : "Source:SSMParam",
            "Description" : "Lookup the image Id using the SSM ParameterStore",
            "Children" : [
                {
                    "Names" : "Name",
                    "Description" : "The name of the parameter to lookup",
                    "Types" : STRING_TYPE,
                    "Default" : "/aws/service/ami-amazon-linux-latest/amzn-ami-hvm-x86_64-ebs"
                }
            ]
        }
    ]
/]
