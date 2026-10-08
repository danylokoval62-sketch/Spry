#!/usr/bin/env bash
# Serve index.html for SPA paths such as /login/: S3 answers 403 for missing keys.
set -euo pipefail
export AWS_PROFILE=new AWS_PAGER=""
DIST=E21I2RKF628XEZ

ETAG=$(aws cloudfront get-distribution-config --id "$DIST" --query ETag --output text)
aws cloudfront get-distribution-config --id "$DIST" --query DistributionConfig > /tmp/dist.json
python3 - <<'PY'
import json
c = json.load(open("/tmp/dist.json"))
items = [{"ErrorCode": code, "ResponsePagePath": "/index.html", "ResponseCode": "200", "ErrorCachingMinTTL": 10} for code in (403, 404)]
c["CustomErrorResponses"] = {"Quantity": len(items), "Items": items}
json.dump(c, open("/tmp/dist.json", "w"))
PY
aws cloudfront update-distribution --id "$DIST" --if-match "$ETAG" --distribution-config file:///tmp/dist.json >/dev/null
echo "DONE. /login/ now serves index.html"
