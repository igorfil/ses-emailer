import boto3
from botocore.exceptions import ClientError
import json
import os

AWS_REGION = os.environ["AWS_REGION"]
SENDER = os.environ["SENDER"]
CHARSET = "UTF-8"

client = boto3.client('ses', region_name=AWS_REGION)

def lambda_handler(event, context):
  message = json.loads(event["Records"][0]["body"])

  recepient = message["to"]
  subject = message["subject"]
  body = message["body"]

  print("Sending email to:" + recepient),

  try:
    response = client.send_email(
        Destination={
            'ToAddresses': [
                recepient,
            ],
        },
        Message={
            'Body': {
                'Html': {
                    'Charset': CHARSET,
                    'Data': body,
                },
                'Text': {
                    'Charset': CHARSET,
                    'Data': body,
                },
            },
            'Subject': {
                'Charset': CHARSET,
                'Data': subject,
            },
        },
        Source=SENDER
    )
  except ClientError as e:
      print(e.response['Error']['Message'])
  else:
      print("Email sent! Message ID:"),
      print(response['MessageId'])
