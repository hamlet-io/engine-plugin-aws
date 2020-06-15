[#ftl]

[#-- Account level Session Manager Resources which are used by other components --]
[#function formatAccountSSMSessionManagerLogGroupName ]
    [#return formatAbsolutePath("ssm", "session-trace" )]
[/#function]

[#function formatAccountSSMSessionManagerLogBucketName ]
    [#return formatName("account", "console", accountObject.Seed)]
[/#function]

[#function formatAccountSSMSessionManagerLogBucketPrefix ]
    [#return "ssmsession/" ]
[/#function]
