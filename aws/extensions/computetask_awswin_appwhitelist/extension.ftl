[#ftl]

[@addExtension
    id="computetask_awswin_appwhitelist"
    aliases=[
        "_computetask_awswin_appwhitelist"
    ]
    description=[
        "MDAC App Whitelist Configuration"
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

[#macro shared_extension_computetask_awswin_appwhitelist_deployment_computetask occurrence ]

    [#local solution = occurrence.Configuration.Solution]
    [#local wlConfig = solution['aws:AppWhitelist']]
    [#local commands = {}]

    [#local whitelist = []]
    [#local whitelist += [
        "Start-Transcript -Path c:\\ProgramData\\Hamlet\\Logs\\user-step.log -Append ;",
        r'echo "App Whitelisting - whitelist.ps1" ;',
        r'$HamletPolicy="c:\ProgramData\Hamlet\Scripts\HamletPolicy.xml" ;'
    ]]
    [#local whitelist += [
        r'$PathRules = @(Get-AppLockerFileInformation -Directory "c:\windows\" -Recurse -FileType exe, script) 2>&1 | Write-Output ;',
        r'$PathRules +=  @(Get-AppLockerFileInformation -Directory "c:\Program Files\" -Recurse -FileType exe, script) 2>&1 | Write-Output ;',
        r'$PathRules +=  @(Get-AppLockerFileInformation -Directory "c:\Program Files (x86)\" -Recurse -FileType exe, script) 2>&1 | Write-Output ;'
        r'$PathRules +=  @(Get-AppLockerFileInformation -Directory "C:\ProgramData\Hamlet\" -Recurse -FileType exe, script) 2>&1 | Write-Output ;'
        r'$PathRules +=  @(Get-AppLockerFileInformation -Directory "C:\ProgramData\Amazon\" -Recurse -FileType exe, script) 2>&1 | Write-Output ;'
    ]]
    [#if isPresent(wlConfig.Allow)]
        [#list wlConfig.Allow.Files as file]
            [#local whitelist += [
                r'$PathRules += @(Get-AppLockerFileInformation -Path "' + file + r'" ) ;'
            ]]
        [/#list]
        [#list wlConfig.Allow.Folders as path]
            [#local whitelist += [
                r'$PathRules += @(Get-AppLockerFileInformation -Directory "' + path + r'" -Recurse -FileType exe, script ) ;'
            ]]
        [/#list]
    [/#if]
    [#local whitelist += [
        r'$PathRules | New-AppLockerPolicy -RuleType Path -User Everyone -Optimize -XML | Out-File -FilePath $HamletPolicy ;' 
    ]]
    [#if wlConfig.Mode == "Audit"]
        [#local whitelist += [
            r'Get-Content -Path $HamletPolicy 2>&1 | Write-Output ;',
            r'# Test-AppLockerPolicy -XmlPolicy $HamletPolicy -Path c:\windows\notepad.exe ;',
            r'# Set-AppLockerPolicy -XmlPolicy $HamletPolicy 2>&1 | Write-Output ;'
        ]]
    [#else]
        [#local whitelist += [
             r'Set-AppLockerPolicy -XmlPolicy $HamletPolicy 2>&1 | Write-Output ;'
        ]]
    [/#if]
    [#local whitelist += [
        r"Stop-Transcript | out-null"
    ]]

    [#local content = {
            "files": {
                "c:\\ProgramData\\Hamlet\\Scripts\\whitelist.ps1" : {
                    "content" : {
                        "Fn::Join" : [
                            "\n",
                            whitelist
                        ]
                    },
                    "mode" : "000755"
                }
            }
        }]
    [#--local content += {
            "commands": {
                "WhitelistSetup" : {
                    "command" : "powershell.exe -ExecutionPolicy Bypass -Command c:\\ProgramData\\Hamlet\\Scripts\\whitelist.ps1",
                    "ignoreErrors" : true
                }
            }
        }--]
    
    [#if ! isPresent(solution['aws:AppWhitelist'])]
        [#local content={}]
    [/#if]

    [@computeTaskConfigSection
        computeTaskTypes=[ COMPUTE_TASK_APPWHITELIST_CONFIG ]
        id="Whitelist"
        priority=7
        engine=AWS_EC2_CFN_INIT_COMPUTE_TASK_CONFIG_TYPE
        content=content
    /]
[/#macro]
