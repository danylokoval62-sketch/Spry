#!/usr/bin/env bash
set -euo pipefail
export AWS_PROFILE=new AWS_PAGER=""
source infra/aws-ids.env

show() {
  local label="$1" arn="$2" region="$3"
  local name value
  name=$(aws acm describe-certificate --certificate-arn "$arn" --region "$region" --query 'Certificate.DomainValidationOptions[0].ResourceRecord.Name' --output text)
  value=$(aws acm describe-certificate --certificate-arn "$arn" --region "$region" --query 'Certificate.DomainValidationOptions[0].ResourceRecord.Value' --output text)
  echo ""
  echo "=== $label ==="
  echo "Type:  CNAME Record"
  echo "Host:  ${name%.spry-koval.me.}"
  echo "Value: ${value%.}"
}

show "api" "$API_CERT" eu-central-1
show "app" "$APP_CERT" us-east-1