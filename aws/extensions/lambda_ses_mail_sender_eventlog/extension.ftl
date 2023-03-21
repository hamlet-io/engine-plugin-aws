[#ftl]

[@addExtension
    id="lambda_ses_mail_sender_eventlog"
    aliases=[
        "_lambda_ses_mail_sender_eventlog"
    ]
    description=[
        "Saves an SES Send email event to a provided S3 bucket location"
    ]
    supportedTypes=[
        LAMBDA_FUNCTION_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_lambda_ses_mail_sender_eventlog_deployment_setup occurrence ]

    [@DefaultLinkVariables enabled=false /]
    [@DefaultCoreVariables enabled=false /]
    [@DefaultEnvironmentVariables enabled=false /]
    [@DefaultBaselineVariables enabled=false /]

    [@lambdaAttributes
        zipFile=[
            r'import boto3',
            r'import json',
            r'import os',
            r'from uuid import uuid4',
            r'from urllib.parse import urlparse',
            r'',
            r'client = boto3.client("s3")',
            r'S3_URL = os.environ["S3_URL"]',
            r'',
            r'def lambda_handler(event, context):',
            r'  """',
            r'  Logs email events to an S3 bucket',
            r'  """',
            r'  for record in event["Records"]:',
            r'      msg = json.loads(record["body"])',
            r'      s3_key = urlparse(S3_URL).path',
            r'      s3_key = s3_key + "/" if not s3_key.endswith("/") and s3_key != "" else s3_key',
            r'      s3_key = f"{s3_key}SES/SendEvent/' + r"{msg['mail']['sendingAccountId']}/{msg['mail']['source']}/{str(uuid4())}.json" +r'"',
            r'      client.put_object(',
            r'          Bucket=urlparse(S3_URL).hostname,',
            r'          Key=s3_key,',
            r'          Body=json.dumps(msg).encode("utf-8")',
            r'      )'
        ]
    /]

[/#macro]
