[#ftl]

[#assign REDIS_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        DNS_ATTRIBUTE_TYPE : {
            "Attribute" : "RedisEndpoint.Address"
        },
        PORT_ATTRIBUTE_TYPE : {
            "Attribute" : "RedisEndpoint.Port"
        }
    }
]
[#assign MEMCACHED_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        DNS_ATTRIBUTE_TYPE : {
            "Attribute" : "ConfigurationEndpoint.Address"
        },
        PORT_ATTRIBUTE_TYPE : {
            "Attribute" : "ConfigurationEndpoint.Port"
        }
    }
]

[#function getAmazonCacheMaintenanceWindow dayofWeek timeofDay timeZone="UTC" ]
    [#local startTime = convertDayOfWeek2DateTime(dayofWeek, timeofDay, timeZone) ]

    [#local endTime = addDateTime(startTime, "mm", 60) ]
    [#local retval = (showDateTime(startTime, "EEE:HH:mm", "UTC")+"-"+showDateTime(endTime, "EEE:HH:mm", "UTC"))?lower_case ]

    [#return retval ]
[/#function]

[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_CACHE_RESOURCE_TYPE
    mappings=REDIS_OUTPUT_MAPPINGS
/]

[@addCWMetricAttributes
    resourceType=AWS_CACHE_RESOURCE_TYPE
    namespace="AWS/ElastiCache"
    dimensions={
        "CacheClusterId" : {
            "Output" : {
                "Attribute" : REFERENCE_ATTRIBUTE_TYPE
            }
        }
    }
/]
