"""make llm-hello: the first call from Part 1, through the Converse API."""

import os

import boto3

brt = boto3.client("bedrock-runtime", region_name=os.environ.get("BEDROCK_REGION", "us-east-1"))
resp = brt.converse(
    modelId=os.environ.get("PARSER_MODEL", "us.anthropic.claude-haiku-4-5-20251001-v1:0"),
    messages=[{"role": "user", "content": [{"text": "In one sentence: what is an ISO week?"}]}],
    inferenceConfig={"maxTokens": 200},
)
print(resp["output"]["message"]["content"][0]["text"])
print(resp["stopReason"], resp["usage"])
