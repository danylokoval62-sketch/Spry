import os
import urllib.parse
from email.message import EmailMessage

import boto3

s3 = boto3.client("s3")
ses = boto3.client("sesv2")


def handler(event, context):
    record = event["Records"][0]
    bucket = record["s3"]["bucket"]["name"]
    key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])
    print(f"report-mailer triggered trigger=s3 event={record['eventName']} key={key}")

    body = s3.get_object(Bucket=bucket, Key=key)["Body"].read()
    name = key.rsplit("/", 1)[-1]
    msg = EmailMessage()
    msg["Subject"] = f"Spry weekly meetings report {name.removesuffix('.csv')}"
    msg["From"] = os.environ["SENDER"]
    msg["To"] = os.environ["RECIPIENTS"]
    msg.set_content(f"Your weekly meetings report is attached ({name}).")
    msg.add_attachment(body, maintype="text", subtype="csv", filename=name)
    ses.send_email(Content={"Raw": {"Data": msg.as_bytes()}})
    print(f"report-mailer sent key={key} to={os.environ['RECIPIENTS']}")
