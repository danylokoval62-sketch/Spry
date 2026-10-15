import json
import logging
import os
from datetime import date, timedelta

import boto3

from app.reports.weekly import build_weekly_report, report_key, week_start

log = logging.getLogger()
log.setLevel(logging.INFO)
s3 = boto3.client("s3")


def parse(event: dict) -> tuple[str, dict]:
    """Return (how the function was invoked, payload) for a direct call or an SQS record."""
    if "Records" in event:
        return "sqs", json.loads(event["Records"][0]["body"])
    return "direct", event


def handler(event, context):
    via, payload = parse(event)
    trigger = payload.get("source") or via
    week = payload.get("week")
    if not week:
        year, num, _ = (date.today() - timedelta(days=7)).isocalendar()
        week = f"{year}-W{num:02d}"
    week_start(week)  # rejects anything that is not an ISO week
    log.info("report-builder triggered trigger=%s via=%s week=%s", trigger, via, week)

    if week == os.environ.get("FAIL_WEEK"):
        raise RuntimeError(f"FAIL_WEEK is set to {week}")

    key = report_key(week)
    s3.put_object(
        Bucket=os.environ["REPORTS_BUCKET"],
        Key=key,
        Body=build_weekly_report(week),
        ContentType="text/csv",
    )
    log.info("report saved key=%s", key)
    return {"key": key}
