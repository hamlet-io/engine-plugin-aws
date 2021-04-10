[#ftl]
[@addResourceGroupInformation
    type=COMPUTECLUSTER_COMPONENT_TYPE
    attributes=[]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_CLOUDWATCH_SERVICE,
            AWS_ELASTIC_COMPUTE_SERVICE,
            AWS_IDENTITY_SERVICE,
            AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE,
            AWS_AUTOSCALING_SERVICE,
            AWS_KEY_MANAGEMENT_SERVICE,
            AWS_SYSTEMS_MANAGER_SERVICE
        ]
/]

[@addResourceGroupAttributeValues
    type=COMPUTECLUSTER_COMPONENT_TYPE
    provider=AWS_PROVIDER
    extensions=[
        {
            "Names" : "Image",
            "Children" : [
                {
                    "Names" : "Source",
                    "Description" : "The source of the image",
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
        }
    ]
/]
