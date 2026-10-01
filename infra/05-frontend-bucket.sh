#!/usr/bin/env bash
set -euo pipefail
export AWS_PROFILE=new AWS_PAGER=""

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
[ "$ACCOUNT_ID" = "649089875356" ] || { echo "WRONG ACCOUNT: $ACCOUNT_ID"; exit 1; }

BUCKET="spry-koval-frontend-$ACCOUNT_ID"
aws s3api create-bucket --bucket "$BUCKET" --region eu-central-1 --create-bucket-configuration LocationConstraint=eu-central-1 >/dev/null 2>&1 || echo "bucket exists"
echo "FRONTEND_BUCKET=$BUCKET" >> infra/aws-ids.env

(cd frontend && npm ci && VITE_API_URL=https://api.spry-koval.me npm run build)
aws s3 sync frontend/dist "s3://$BUCKET" --delete
echo "DONE. Bucket: $BUCKET"