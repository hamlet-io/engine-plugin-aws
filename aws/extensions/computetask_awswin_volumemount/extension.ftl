[#ftl]

[@addExtension
    id="computetask_awswin_volumemount"
    aliases=[
        "_computetask_awswin_volumemount"
    ]
    description=[
        "Uses windows commands to format and mount volumes"
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

[#macro shared_extension_computetask_awswin_volumemount_deployment_computetask occurrence ]

    [#local storageProfile = _context.StorageProfile ]
    [#local volumes = (storageProfile.Volumes)!{}]

    [#local files = {}]
    [#local commands = {}]

    [#-- Support for data volumes as linked components to single instances --]
    [#if occurrence.Core.Type == EC2_COMPONENT_TYPE ]

        [#local zoneResources = occurrence.State.Resources.Zones]
        [#list zones as zone]
            [#if multiAZ || (zones[0].Id = zone.Id)]
                [#local zoneEc2InstanceId = zoneResources[zone.Id]["ec2Instance"].Id ]
                [#list (_context.VolumeMounts)![] as mountId,volumeMount ]
                    [#local dataVolume = _context.DataVolumes[mountId]!{} ]
                    [#if dataVolume?has_content ]
                        [#local zoneVolume = (dataVolume[zone.Id].VolumeId)!"" ]
                        [#if zoneVolume?has_content ]
                            [#if ! ( getCLODeploymentUnitAlternative() == "replace1" ) ]
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
                            [/#if]

                            [#local volumes += {
                                mountId : {
                                    "MountPath" : volumeMount.MountPath,
                                    "Device" : volumeMount.DeviceId,
                                    "DataVolume" : true
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
        [#local diskId = 0]

        [#if (volume.Enabled)!true
                && ((volume.MountPath)!"")?has_content
                && ((volume.Device)!"")?has_content ]

            [#local diskId = diskId + 1]
            [#local deviceId = volume.Device]
            [#local osMount = volume.MountPath]
            [#local dataVolume = (volume.DataVolume)!false]

        [#else]
            [#continue]
        [/#if]

        [#local scriptName = "data_volume_mount_" + replaceAlphaNumericOnly(deviceId) ]

        [#local script = [
            'select disk ${diskId} ',
            'attributes disk clear readonly ',
            'online disk ',
            'convert mbr ',
            'create partition primary '
        ]]
        
        [#if osMount?length == 1 ]
            [#local script += [ 'assign letter="${osMount}" ' ]]
        [#else]
            [#local script += [ 'assign mount="${osMount}" ' ]]
        [/#if]

        [#local execScript = [
            'Start-Transcript -Path c:\\ProgramData\\Hamlet\\Logs\\${scriptName}.log ;',
            'echo "Starting volume mount" ;',
            'mkdir ${osMount} ;',
            'diskpart /s c:\\ProgramData\\Hamlet\\Scripts\\${scriptName}.txt ;',
            'Stop-Transcript | out-null'
        ]]

        [#local files += {
            "c:\\ProgramData\\Hamlet\\Scripts\\${scriptName}.txt" : {
                "content" : {
                    "Fn::Join" : [
                        "\n",
                        script
                    ]
                },
                "mode" : "000755"
            }
        }]

        [#local files += {
            "c:\\ProgramData\\Hamlet\\Scripts\\${scriptName}.ps1" : {
                "content" : {
                    "Fn::Join" : [
                        "\n",
                        execScript
                    ]
                },
                "mode" : "000755"
            }
        }]

        [#local commands += {
            scriptName : {
                "command" : "powershell.exe -ExecutionPolicy Bypass -Command c:\\ProgramData\\Hamlet\\Scripts\\${scriptName}.ps1",
                "ignoreErrors" : false
            }
        }]

    [/#list]


    [#local content = {}]
    [#if files?has_content || commands?has_content ]
        [#local content = {
            "files" : files,
            "commands" : commands
        }]
    [/#if]

    [@computeTaskConfigSection
        computeTaskTypes=[ 
            COMPUTE_TASK_DATA_VOLUME_MOUNTING, 
            COMPUTE_TASK_SYSTEM_VOLUME_MOUNTING 
        ]
        id="VolumeMount"
        priority=1
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content=content
    /]

[/#macro]
