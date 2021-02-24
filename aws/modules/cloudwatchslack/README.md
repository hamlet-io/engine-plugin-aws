# alarmslack Hamlet Module

This is a Hamlet Deploy module.

See docs.hamlet.io for more information.

## Description
Sends Slack notifications based on cloudwatch alarms.

The module implements the components that enable the triggering of the alarm, and defines a new `AlertProfile` based on the parameter provided. 

This `AlertProfile` is intended to be used with components external to the module itself, through component Profile configuration or DeploymentProfiles.

## Requirements
- AWS Provider Plugin
- An existing Slack Channel

## Usage
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "$id": "https://hamlet.io/schema/latest/blueprint/module-alarmslack-schema.json",
  "definitions": {
    "alarmslack": {
      "type": "object",
      "patternProperties": {
        "^[A-Za-z_][A-Za-z0-9_]*$": {
          "properties": {
            "slackChannel": {
              "type": "object",
              "description": "The slack channel to send alerts to"
            },
            "webHookUrl": {
              "type": "object",
              "description": "The slack incoming webhook URL to use - Encryption is recommended"
            },
            "alertSeverity": {
              "type": "object",
              "description": "The lowest severity alerts to include in notifications",
              "default": "info"
            },
            "alertProfile": {
              "type": "object",
              "description": "The alert profile id to use for enabling notifications",
              "default": "default"
            },
            "kmsPrefix": {
              "type": "object",
              "description": "The KMS prefix used for encrypted values",
              "default": "base64:"
            },
            "lambdaSourceUrl": {
              "type": "object",
              "description": "A URL to the lambda zip package for sending alerts",
              "default": "https://github.com/hamlet-io/lambda-cloudwatch-slack/releases/download/v1.1.0/cloudwatch-slack.zip"
            },
            "lambdaSourceHash": {
              "type": "object",
              "description": "A sha1 hash of the lambda image to ensure its the right one",
              "default": "8f194db4f6ed2b826387112df144f188451ba6db"
            },
            "namePrefix": {
              "type": "object",
              "description": "A prefix appended to component names and deployment units to ensure uniquness",
              "default": "alarmslack"
            },
            "tier": {
              "type": "object",
              "description": "The tier to use to host the components",
              "default": "mgmt"
            }
          },
          "additionalProperties": false,
          "required": [
            "slackChannel",
            "webHookUrl"
          ]
        }
      }
    }
  }
}
```