import base64
import json
import logging
import os
import time
from datetime import date

import jwt
from botocore.exceptions import ClientError

from app.ai.agenda import (
    PARSER_MODEL,
    PROMPT_VERSION,
    AgendaParseError,
    cost_usd,
    parse_agenda,
)

log = logging.getLogger()
log.setLevel(logging.INFO)

MAX_CHARS = 10_000
AUTHORITY = os.environ.get("COGNITO_AUTHORITY", "")
CLIENT_ID = os.environ.get("COGNITO_CLIENT_ID", "")
# This function is outside the VPC, so it can fetch Cognito's keys (cached between calls).
_jwks = jwt.PyJWKClient(f"{AUTHORITY}/.well-known/jwks.json")


def verify_cognito_token(header: str) -> dict:
    """Return the claims of a valid Cognito ID token; raise jwt.PyJWTError otherwise."""
    token = header.removeprefix("Bearer ").strip()
    key = _jwks.get_signing_key_from_jwt(token).key
    claims = jwt.decode(token, key, algorithms=["RS256"], audience=CLIENT_ID, issuer=AUTHORITY)
    if claims.get("token_use") != "id":
        raise jwt.InvalidTokenError("not an ID token")
    return claims


def reply(status: int, body: dict) -> dict:
    return {
        "statusCode": status,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(body),
    }


def handler(event, context):
    try:
        user = verify_cognito_token(event["headers"].get("authorization", ""))
    except (jwt.PyJWTError, KeyError):
        return reply(401, {"error": "sign in to parse an agenda"})

    raw = event.get("body") or ""
    if event.get("isBase64Encoded"):
        raw = base64.b64decode(raw).decode()
    try:
        body = json.loads(raw)
        text, today, tz = body["text"], date.fromisoformat(body["today"]), str(body["tz"])[:64]
        if not isinstance(text, str) or not text.strip():
            raise ValueError("text")
    except (ValueError, KeyError, TypeError):
        return reply(400, {"error": "expected JSON with text, today (YYYY-MM-DD) and tz"})
    if len(text) > MAX_CHARS:
        return reply(413, {"error": f"text is longer than {MAX_CHARS} characters"})

    started = time.monotonic()
    try:
        agenda, usage = parse_agenda(text, today, tz)
    except AgendaParseError as e:
        return reply(422, {"error": str(e)})
    except ClientError as e:
        if e.response["Error"]["Code"] == "ThrottlingException":
            return reply(429, {"error": "the model is busy, try again in a moment"})
        log.exception("bedrock call failed")
        return reply(502, {"error": "the model is unavailable"})

    log.info(
        json.dumps(
            {
                "event": "agenda_parsed",
                "user": user["sub"],
                "model": PARSER_MODEL,
                "prompt_version": PROMPT_VERSION,
                **usage,
                "latency_ms": int((time.monotonic() - started) * 1000),
                "cost_usd": cost_usd(PARSER_MODEL, usage),
            }
        )
    )
    return reply(
        200,
        {
            "agenda": agenda.model_dump(mode="json"),
            "model": PARSER_MODEL,
            "prompt_version": PROMPT_VERSION,
        },
    )
