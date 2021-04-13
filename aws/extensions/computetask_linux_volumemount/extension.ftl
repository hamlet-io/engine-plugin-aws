[#ftl]

[@addExtension
    id="computetask_linux_volumemount"
    aliases=[
        "_computetask_linux_volumemount"
    ]
    description=[
        "Uses linux commands to format and mount volumes"
    ]
    supportedTypes=[
        EC2_COMPONENT_TYPE,
        ECS_COMPONENT_TYPE,
        COMPUTECLUSTER_COMPONENT_TYPE,
        BASTION_COMPONENT_TYPE
    ]
    scopes=[
        COMPUTETASK_EXTENSION_SCOPE
    ]
/]

[#macro shared_extension_computetask_linux_volumemount_deployment_computetask occurrence ]

    [#local storageProfile = _context.StorageProfile ]
    [#local volumes = (storageProfile.Volumes)!{}]

    [#local files = {}]
    [#local commands = {}]

    [#-- Support for data volumes as linked components to single instances --]
    [#if occurrence.Core.Type == EC2_COMPONENT_TYPE ]
        [#list zones as zone]
            [#if multiAZ || (zones[0].Id = zone.Id)]
                [#local zoneEc2InstanceId = zoneResources[zone.Id]["ec2Instance"].Id ]
                [#list (_context.VolumeMounts)![] as mountId,volumeMount ]
                    [#local dataVolume = _context.DataVolumes[mountId]!{} ]
                    [#if dataVolume?has_content ]
                        [#local zoneVolume = (dataVolume[zone.Id].VolumeId)!"" ]
                        [#if zoneVolume?has_content ]
                            [@createEBSVolumeAttachment
                                id=formatDependentResourceId(
                                    AWS_EC2_EBS_ATTACHMENT_RESOURCE_TYPE,
                                    zoneEc2InstanceId,
                                    mountId
                                )
                                device=volumeMount.DeviceId
                                instanceId=zoneEc2InstanceId
                                volumeId=zoneVolume
                            /]

                            [#local volumes += {
                                mountId : {
                                    "MountPath" : volumeMount.MountPath,
                                    "Device" : volumeMount.DeviceId
                                }
                            }]

                        [/#if]
                    [/#if]
                [/#list]
            [/#if]
        [/#list]
    [/#if]

    [#list volumes as id,volume ]

        [#local deviceId = ""]
        [#local osMount = ""]

        [#if (volume.Enabled)!true
                && ((volume.MountPath)!"")?has_content
                && ((volume.Device)!"")?has_content ]

            [#local deviceId = volume.Device]
            [#local osMount = volume.MountPath]

        [#else]
            [#continue]
        [/#if]

        [#local scriptName = "data_volume_mount_" + replaceAlphaNumericOnly(deviceId) ]

        [#local script = [
            r'#!/bin/bash',
            r'set -euo pipefail',
            'exec > >(tee /var/log/hamlet_cfninit/${scriptName}.log | logger -t ${scriptName} -s 2>/dev/console) 2>&1',

            'device_id="${deviceId}"',
            'os_mount="${osMount}"',

            r'# Ensure device exists',
            r'if [[ ! -b "${device_id}" ]]; then'
            r'  echo "${device_id} not available"',
            r'  exit 1',
            r'fi',

            r'# Create filesystem if required',
            r'if [[ -z "$(file  -sL $device_id | grep "ext" || test $? =1 )" ]]; then',
            r'  mkfs -t ext4 "${device_id}"',
            r'else',
            r'  echo "Using existing filesystem on ${device_id}"',
            r'fi',

            r'# Mount device to mount point',
            r'for local_mount_point in $(findmnt -frnuo TARGET --source "${device_id}" || test $? = 1 ); do',
            r'  if [[ "${local_mount_point}" == "${os_mount}" ]]; then',
            r'      echo "${device_id} already mounted to ${os_mount}"',
            r'      exit 0',
            r'  else',
            r'      echo "${device_id} is not mounted to ${os_mount}"',
            r'  fi',
            r'done',
            r'mkdir -p "${os_mount}"',
            r'mount "${device_id}" "${os_mount}"',

            r'# Permanent mount',
            r'if [[ -z "$( grep "${device_id}" /etc/fstab || test $? = 1 )" ]]; then',
            r'  if [[ -n "$( findmnt -frnuo SOURCE --source "${device_id}" || test $? = 1 )" ]]; then',
            r'      echo -e "${device_id} ${os_mount} ext4 defaults 0 0" >> /etc/fstab',
            r'    else',
            r'        echo "device ${device_id} is not mounted"',
            r'        exit 1',
            r'    fi',
            r'else',
            r'  echo "permanent mount setup ${device_id} to ${os_mount}"',
            r'fi'
        ]]

        [#local files += {
            "/opt/hamlet_cfninit/${scriptName}.sh" : {
                "content" : {
                    "Fn::Join" : [
                        "\n",
                        script
                    ]
                },
                "mode" : "000755"
            }
        }]

        [#local commands += {
            scriptName : {
                "command" : "/opt/hamlet_cfninit/${scriptName}.sh",
                "ignoreErrors" : false
            }
        }]

    [/#list]


    [#local content = {}]
    [#if files?has_content && commands?has_content ]
        [#local content = {
            "files" : files,
            "commands" : commands
        }]
    [/#if]

    [@computeTaskConfigSection
        computeTaskTypes=[ COMPUTE_TASK_DATA_VOLUME_MOUNTING ]
        id="VolumeMount"
        priority=1
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content=content
    /]

[/#macro]
