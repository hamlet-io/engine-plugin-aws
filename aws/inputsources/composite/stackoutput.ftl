[#ftl]

[#-- Get stack output --]
[#function aws_input_composite_stackoutput_filter outputFilter ]
    [#return {
        "Account" : (outputFilter.Account)!accountObject.ProviderId,
        "Region" : outputFilter.Region,
        "DeploymentUnit" : outputFilter.DeploymentUnit
    }]
[/#function]
