#!/usr/bin/env bash
set -euo pipefail
export AWS_PROFILE=new AWS_PAGER=""

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
[ "$ACCOUNT_ID" = "649089875356" ] || { echo "WRONG ACCOUNT: $ACCOUNT_ID"; exit 1; }

API_CERT=$(aws acm request-certificate --domain-name api.spry-koval.me --validation-method DNS --region eu-central-1 --query CertificateArn --output text)
APP_CERT=$(aws acm request-certificate --domain-name app.spry-koval.me --validation-method DNS --region us-east-1 --query CertificateArn --output text)
echo "API_CERT=$API_CERT" >> infra/aws-ids.env
echo "APP_CERT=$APP_CERT" >> infra/aws-ids.env
sleep 15

echo "=== DNS record for api (Name / Type / Value) ==="
aws acm describe-certificate --certificate-arn "$API_CERT" --region eu-central-1 --query 'Certificate.DomainValidationOptions[0].ResourceRecord' --output text
echo "=== DNS record for app (Name / Type / Value) ==="
aws acm describe-certificate --certificate-arn "$APP_CERT" --region us-east-1 --query 'Certificate.DomainValidationOptions[0].ResourceRecord' --output text

REGISTRY="$ACCOUNT_ID.dkr.ecr.eu-central-1.amazonaws.com"
TAG=$(git rev-parse HEAD)
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin "$REGISTRY"
docker build --platform linux/amd64 -t "$REGISTRY/spry-backend:$TAG" backend
docker push "$REGISTRY/spry-backend:$TAG"
echo "TAG=$TAG" >> infra/aws-ids.env
echo "DONE. TAG=$TAG"