[#ftl]
[#macro aws_datavolume_cf_deployment_generationcontract_solution occurrence ]
    [@addDefaultGenerationContract subsets=["template", "epilogue"] /]
[/#macro]

[#macro aws_datavolume_cf_deployment_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]
    [#local resources = occurrence.State.Resources]

    [#local manualSnapshotId = resources["manualSnapshot"].Id]
    [#local manualSnapshotName = getExistingReference(manualSnapshotId, NAME_ATTRIBUTE_TYPE)]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "Encryption"] )]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]

    [#local cmkKeyId = baselineComponentIds["Encryption" ]]

    [#list resources["Zones"] as zoneId, zoneResources ]
        [#local volumeId = zoneResources["ebsVolume"].Id ]
        [#local volumeName = zoneResources["ebsVolume"].Name ]

        [#local volumeTags = getOccurrenceCoreTags(
                                    occurrence,
                                    volumeName,
                                    "",
                                    false)]

        [#if deploymentSubsetRequired(DATAVOLUME_COMPONENT_TYPE, true)]
            [@createEBSVolume
                id=volumeId
                tags=volumeTags
                size=solution.Size
                volumeType=solution.VolumeType?remove_beginning("aws:")
                encrypted=solution.Encrypted
                kmsKeyId=cmkKeyId
                provisionedIops=solution.ProvisionedIops
                zone=getZones()?filter(zone -> zone.Id == zoneId)[0]
                snapshotId=manualSnapshotName
            /]
        [/#if]
    [/#list]

    [#if deploymentSubsetRequired("epilogue", false)]
        [@addToDefaultBashScriptOutput
            content=
            [
                "case $\{STACK_OPERATION} in",
                "  create|update)"
            ] +
            pseudoStackOutputScript(
                "Manual Snapshot",
                { manualSnapshotId : "" }
            ) +
            [
                "       ;;",
                "       esac"
            ]
        /]
    [/#if]
[/#macro]
