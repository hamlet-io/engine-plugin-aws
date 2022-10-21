[#ftl]

[#macro aws_user_cf_state occurrence parent={} ]
    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]

    [#local userId = formatResourceId(AWS_IAM_USER_RESOURCE_TYPE, core.Id) ]
    [#local userArn = getExistingReference(userId, ARN_ATTRIBUTE_TYPE)]

    [#local encryptionScheme = (solution.GenerateCredentials.EncryptionScheme)?has_content?then(
                    solution.GenerateCredentials.EncryptionScheme?ensure_ends_with(":"),
                    "" )]

    [#local linkResources = {} ]

    [#local transferUserName = core.Name ]
    [#local transferUser = false]

    [#list solution.Links?values as link]
        [#if link?is_hash]
            [#local linkTarget = getLinkTarget(occurrence, link, false) ]

            [@debug message="Link Target" context=linkTarget enabled=false /]

            [#if !linkTarget?has_content]
                [#continue]
            [/#if]

            [#switch linkTarget.Core.Type]
                [#case FILETRANSFER_COMPONENT_TYPE]
                    [#local linkResources = mergeObjects( linkResources, {
                        "transferUsers" : {
                            link.Id  :{
                                "Id" : formatResourceId(AWS_TRANSFER_USER_RESOURCE_TYPE, core.Id, link.Id ),
                                "UserName" : transferUserName,
                                "Type" : AWS_TRANSFER_USER_RESOURCE_TYPE
                            }
                        },
                        "transferRole" : {
                            "Id" : formatResourceId(AWS_IAM_ROLE_RESOURCE_TYPE, core.Id, "transfer" ),
                            "Type" : AWS_IAM_ROLE_RESOURCE_TYPE
                        }
                    })]
                    [#local transferUser = true]
                    [#break]
            [/#switch]
        [/#if]
    [/#list]

    [#-- Use short full name for user as there is a length limit of 64 chars --]
    [#assign componentState =
        {
            "Resources" : {
                "user" : {
                    "Id" : userId,
                    "Name" : core.ShortFullName,
                    "Type" : AWS_IAM_USER_RESOURCE_TYPE,
                    "Deployed" : true
                },
                "apikey" : {
                    "Id" : formatDependentResourceId(AWS_APIGATEWAY_APIKEY_RESOURCE_TYPE, userId),
                    "Name" : core.FullName,
                    "Type" : AWS_APIGATEWAY_APIKEY_RESOURCE_TYPE
                }
            } + linkResources,
            "Attributes" : {
                "USERNAME" : getExistingReference(userId),
                "ARN" : userArn,
                "ACCESS_KEY" : getExistingReference(userId, USERNAME_ATTRIBUTE_TYPE),
                "SECRET_KEY" : getExistingReference(userId, PASSWORD_ATTRIBUTE_TYPE)?ensure_starts_with(encryptionScheme)
            } +
            attributeIfTrue(
                "FILETRANSFER_USERNAME",
                transferUser,
                transferUserName
            ),
            "Roles" : {
                "Inbound" : {
                    "invoke" : {
                        "Principal" : userArn
                    }
                },
                "Outbound" : {}
            }
        }
    ]
[/#macro]
