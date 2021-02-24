# no_master_vpc Hamlet Module 

This is a Hamlet Deploy module.

See docs.hamlet.io for more information.
## Description
<!-- provide a summary of the purpose and use-case for your module -->
Disables the default `vpc` included by the AWS Provider Plugin.

## Requirements
- AWS Provider Plugin

## Usage
<!--
 Provide a JSONSchema for module configuration.

 Generate:
 hamlet schema -i mock create-schemas -t module -u <module-name>
-->
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "$id": "",
  "definitions": {
    "no_master_vpc": {
      "type": "object"
    }
  }
}
```

Note: This module does not accept parameters.