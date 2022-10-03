# aws_service_log_db Hamlet Module

This is a Hamlet Deploy module.

See docs.hamlet.io for more information.

## Description

Provides a Glue/Athena database of AWS services which are stored in S3. This makes the logs available in Athena to run queries over

Logs are assumed to be installed in the opsdata baseline data store and to not have any extra prefixes when they can be stored under the AWSLogs/ prefix

The whole deployment is available as a single deployment:Unit `aws-service-logs`

## Requirements

- AWS Provider Plugin

## Usage

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "$id": "",
  "definitions": {
    "aws_service_log_db": {
      "type": "object"
    }
  }
}
```

Note: This module does not accept parameters.
