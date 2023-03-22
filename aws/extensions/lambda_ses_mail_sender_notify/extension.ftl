[#ftl]

[@addExtension
    id="lambda_ses_mail_sender_notify"
    aliases=[
        "_lambda_ses_mail_sender_notify"
    ]
    description=[
        "Sends an SES send event through to a set of nominated recipients"
    ]
    supportedTypes=[
        LAMBDA_FUNCTION_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_lambda_ses_mail_sender_notify_deployment_setup occurrence ]

    [@DefaultLinkVariables enabled=false /]
    [@DefaultCoreVariables enabled=false /]
    [@DefaultEnvironmentVariables enabled=false /]
    [@DefaultBaselineVariables enabled=false /]

    [@lambdaAttributes
        zipFile=[
            r'import boto3',
            r'import json',
            r'import os',
            r'',
            r'client = boto3.client("ses")',
            r'SENDER_ADDRESS = os.environ["SENDER_ADDRESS"]',
            r'REPLY_TO_ADDRESS = os.environ.get("REPLY_TO_ADDRESS", SENDER_ADDRESS)',
            r'',
            r'BOUNCE_ADDRESSES = os.environ.get("BOUNCE_ADDRESSES","").split(",")',
            r'',
            r'def lambda_handler(event, context):',
            r'  """',
            r'  Sends bounce or complaint emails to nominated addresses',
            r'  """',
            r'  for record in event["Records"]:',
            r'      msg = json.loads(record["body"])',
            r'      try:',
            r'          email_subject = msg["mail"]["commonHeaders"]["subject"]',
            r'      except KeyError:',
            r'          email_subject = "Subject Unknown"',
            r'      event_type = msg["eventType"]',
            r'      subject = f"Email Event - {event_type} - {email_subject}"',
            r'      body = json.dumps(msg, indent=2)',
            r'',
            r'      if event_type in ["Bounce","Complaint"] and BOUNCE_ADDRESSES:',
            r'          client.send_email(',
            r'              Source=SENDER_ADDRESS,',
            r'              Destination={',
            r'                  "ToAddresses": BOUNCE_ADDRESSES',
            r'              },',
            r'              Message={',
            r'                  "Subject": {',
            r'                      "Data": subject',
            r'                  },',
            r'                  "Body": {',
            r'                      "Text" : {',
            r'                          "Data": body',
            r'                      }',
            r'                  }',
            r'              },',
            r'              ReplyToAddresses=[ REPLY_TO_ADDRESS ]',
            r'          )'
        ]
    /]

[/#macro]
