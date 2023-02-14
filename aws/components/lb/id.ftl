[#ftl]
[@addResourceGroupInformation
    type=LB_COMPONENT_TYPE
    attributes=[]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_ELASTIC_LOAD_BALANCER_SERVICE,
            AWS_WEB_APPLICATION_FIREWALL_SERVICE,
            AWS_KINESIS_SERVICE,
            AWS_CLOUDWATCH_SERVICE,
            AWS_IDENTITY_SERVICE,
            AWS_APIGATEWAY_SERVICE
        ]
/]

[@addResourceGroupAttributeValues
    type=LB_COMPONENT_TYPE
    provider=AWS_PROVIDER
    extensions=[
        {
            "Names" : "engine:application",
            "Description" : "When handling HTTP Traffic apply the following configuration",
            "Children" : [
                {
                    "Names" : "DropInvalidHeaders",
                    "Description" : "Drop any headers which do not comply with header standards",
                    "Types": BOOLEAN_TYPE,
                    "Default" : true
                }
            ]
        }
    ]
/]

[@addResourceGroupInformation
    type=LB_PORT_COMPONENT_TYPE
    attributes=[]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_ELASTIC_LOAD_BALANCER_SERVICE,
            AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE,
            AWS_ROUTE53_SERVICE,
            AWS_CERTIFICATE_MANAGER_SERVICE
        ]
/]

[@addResourceGroupAttributeValues
    type=LB_PORT_COMPONENT_TYPE
    provider=AWS_PROVIDER
    extensions=[
        {
            "Names" : "Forward",
            "Children" : [
                {
                    "Names" : "TargetType",
                    "Values" : [ "shared:ip", "shared:instance", "alb", "lambda"]
                }
            ]
        }
    ]
/]

[@addResourceGroupInformation
    type=LB_BACKEND_COMPONENT_TYPE
    attributes=[]
    provider=AWS_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AWS_ELASTIC_LOAD_BALANCER_SERVICE,
            AWS_VIRTUAL_PRIVATE_CLOUD_SERVICE
        ]
/]
