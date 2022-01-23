# log_encryption Hamlet Module

This is a Hamlet Deploy module.

See docs.hamlet.io for more information.

## Description

Provides a deployment Profile and Logging Profile to enable at-rest encryption of log storage for CloudWatch

## Requirements

- AWS Provider Plugin

## Usage

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "$id": "",
  "definitions": {
    "log_encryption": {
      "type": "object"
    }
  }
}
```

Note: This module does not accept parameters.
