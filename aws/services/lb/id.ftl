[#ftl]

[#-- Resources --]
[#assign AWS_LB_RESOURCE_TYPE = "lb" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_LOAD_BALANCER_SERVICE
    resource=AWS_LB_RESOURCE_TYPE
/]
[#assign AWS_ALB_RESOURCE_TYPE = "alb" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_LOAD_BALANCER_SERVICE
    resource=AWS_ALB_RESOURCE_TYPE
/]

[#assign AWS_LB_CLASSIC_RESOURCE_TYPE = "lbClassic" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_LOAD_BALANCER_SERVICE
    resource=AWS_LB_CLASSIC_RESOURCE_TYPE
/]
[#assign AWS_LB_APPLICATION_RESOURCE_TYPE = "lbApplication" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_LOAD_BALANCER_SERVICE
    resource=AWS_LB_APPLICATION_RESOURCE_TYPE
/]
[#assign AWS_LB_NETWORK_RESOURCE_TYPE = "lbNetwork" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_LOAD_BALANCER_SERVICE
    resource=AWS_LB_NETWORK_RESOURCE_TYPE
/]

[#assign AWS_ALB_LISTENER_RESOURCE_TYPE = "listener" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_LOAD_BALANCER_SERVICE
    resource=AWS_ALB_LISTENER_RESOURCE_TYPE
/]

[#assign AWS_ALB_LISTENER_RULE_RESOURCE_TYPE = "listenerRule" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_LOAD_BALANCER_SERVICE
    resource=AWS_ALB_LISTENER_RULE_RESOURCE_TYPE
/]

[#assign AWS_ALB_TARGET_GROUP_RESOURCE_TYPE = "tg" ]
[@addServiceResource
    provider=AWS_PROVIDER
    service=AWS_ELASTIC_LOAD_BALANCER_SERVICE
    resource=AWS_ALB_TARGET_GROUP_RESOURCE_TYPE
/]
