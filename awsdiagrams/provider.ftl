[#ftl]

[#--
    AWS Supporting provider for the Diagrams Plugin https://github.com/hamlet-io/engine-plugin-diagrams
    Provides resource mappings for AWS resources
--]

[#assign AWSDIAGRAMS_PROVIDER = "awsdiagrams"]

[#-- Load all servicess --]
[@includeAllServicesConfiguration
    provider=AWS_PROVIDER
/]

[@includeAllServicesConfiguration
    provider=AWSDIAGRAMS_PROVIDER
/]
