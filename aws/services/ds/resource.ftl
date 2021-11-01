[#ftl]

[#assign DIRECTORY_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        }
    }
]
[@addOutputMapping
    provider=AWS_PROVIDER
    resourceType=AWS_DIRECTORY_RESOURCE_TYPE
    mappings=DIRECTORY_OUTPUT_MAPPINGS
/]

[#macro createDSInstance id name
    type
    size
    masterPassword=""
    enableSSO=false
    fqdName=""
    shortName=""
    vpcSettings=""
    dependencies=[]
]
    [@cfResource
    id=id
    type="AWS::DirectoryService::"+type
    properties=
        {
            "Password": masterPassword,
            "EnableSso": enableSSO,
            "Name": fqdName,
            "VpcSettings": vpcSettings
        } +
        attributeIfContent(
            "Edition",
            (type="MicrosoftAD")?then(size,"")
        ) +
        attributeIfContent(
            "ShortName",
            shortName
        ) +
        attributeIfContent(
            "Size",
            (type="MicrosoftAD")?then("",size)
        )
    dependencies=dependencies
    outputs=
        DIRECTORY_OUTPUT_MAPPINGS
    /]
[/#macro]


[#function createADConnectorScript
        connectorId
        directoryIdEnvVar
        region
        passwordSecretId
        connectorSize
        vpcId
        subnetIds
        adFQDN
        adDNSIPs
        tags]

    [#local connectorTags = tags?map(x -> "Key='${x.Key}',Value='${x.Value}'" )?join(" ")]
    [#local passwordSecretArn = getExistingReference(passwordSecretId, ARN_ATTRIBUTE_TYPE)]
    [#local vpc = getExistingReference(vpcId)]
    [#local adDNSIPs = adDNSIPs?has_content?then(adDNSIPs?join(","), "")]
    [#local subnetIds = subnetIds?join(",")]

    [#return
        [
            r'case ${STACK_OPERATION} in',
            r'  create|update)',
            '      vpc_id="${vpc}"',
            '      subnets="${subnetIds}"',
            '      ad_fqdn="${adFQDN}"',
            '      ad_dns_ips="${adDNSIPs}"',
            '      connector_size="${connectorSize}"',
            '      region=${region}',
            '      ad_connector_secret_value="$( aws --region "${region}" secretsmanager get-secret-value --secret-id "${passwordSecretArn}" --query "SecretString" || exit $? )"',
            r'     ad_username="$( jq -r ". | fromjson | .username" <<< "${ad_connector_secret_value}" )"',
            r'     ad_password="$( jq -r ". | fromjson | .password" <<< "${ad_connector_secret_value}" )"',
            r'     connect_settings="VpcId=${vpc_id},SubnetIds=${subnets},CustomerDnsIps=${ad_dns_ips},CustomerUserName=${ad_username}"',
            r'     directory_id="$(aws --region "${region}" ds connect-directory --name "${ad_fqdn}" --password "${ad_password}" --size "${connector_size}" --connect-settings "${connect_settings}" --tags ' + connectorTags + r' --output text --query "DirectoryId" || exit $?)"',
            '      ${directoryIdEnvVar}=' + r'"${directory_id}"',
            r'     # watch setup',
            r'     for ((i=1;i<=100;i++)); do',
            r'        stage="$(aws --region "${region}" ds describe-directories --directory-id "${direcotory_id}" --output text --query "DirectoryDescriptions[0].Stage" )"',
            r'        case',
            r'          Active)',
            r'            info "AD Connector ${direcotory_id} setup complete"'
        ] +
            pseudoStackOutputScript(
                "AD Connector",
                { connectorId : r'${directory_id}' },
                "adconnector"
            ) +
        [
            r'            break',
            r'            ;;',
            r'          Failed)',
            r'            stage_reason="$(aws --region "${region}" ds describe-directories --directory-id "${direcotory_id}" --output text --query "DirectoryDescriptions[0].StageReason" )"',
            r'            fatal "AD Connector ${direcotory_id} setup failed | ${stage_reason}"',
            r'            exit 128',
            r'            ;;',
            r'         esac',
            r'         [[ $i == 99 ]] && fatal "AD Connector ${directory_id} setup timeout" && exit 64',
            r'         sleep 15s',
            r'      done',
            r'      ;;',
            r'  delete)',
            '       directory_id="${getExistingReference(connectorId)}"',
            r'      aws --region "${region}" ds delete-directory --direcotory-id "${directory_id}"',
            r'      ;;',
            r'esac'
        ]
    ]
[/#function]
