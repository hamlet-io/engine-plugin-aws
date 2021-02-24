# consolidatelogs Hamlet Module

This is a Hamlet Deploy module.

See docs.hamlet.io for more information.

## Description
<!-- provide a summary of the purpose and use-case for your module -->
Solution-wide consolidation of logs into ops data bucket.

Consolidation is performed through a DeploymentProfile created within the module.

## Requirements
- AWS Provider Plugin

## Usage
<!--
 Provide an example configuration of the Module in a Solution.

 Ensure all parameters are listed, with "/* optional */" where applicable
-->
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "$id": "",
  "definitions": {
    "consolidatelogs": {
      "type": "object",
      "patternProperties": {
        "^[A-Za-z_][A-Za-z0-9_]*$": {
          "properties": {
            "namePrefix": {
              "type": "object",
              "description": "A prefix appended to component names and deployment units to ensure uniquness"
            },
            "deploymentProfile": {
              "type": "object",
              "description": "The deployment profile id to enable log consolidation on."
            },
            "lambdaSourceUrl": {
              "type": "object",
              "description": "A URL to the lambda zip package for sending alerts",
              "default": "https://github.com/hamlet-io/lambda-log-processors/releases/download/v1.0.2/cloudwatch-firehose.zip"
            },
            "lambdaSourceHash": {
              "type": "object",
              "description": "A sha1 hash of the lambda image to validate the correct one",
              "default": "3a6b1ce462aaa203477044cfe83c66f128381434"
            },
            "tier": {
              "type": "object",
              "description": "The tier to use to host the components",
              "default": "mgmt"
            }
          },
          "additionalProperties": false,
          "required": [
            "deploymentProfile"
          ]
        }
      }
    }
  }
}
```