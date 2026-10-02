#!/usr/bin/env bash
set -euo pipefail
export AWS_PROFILE=new AWS_PAGER=""
source infra/aws-ids.env

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
[ "$ACCOUNT_ID" = "649089875356" ] || { echo "WRONG ACCOUNT: $ACCOUNT_ID"; exit 1; }

cat > /tmp/trust.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Federated": "arn:aws:iam::$ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"},
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
        "token.actions.githubusercontent.com:sub": "repo:danylokoval62-sketch@232208209/Spry@1400436674:ref:refs/heads/main"
      }
    }
  }]
}
EOF

cat > /tmp/perm.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {"Effect": "Allow", "Action": "ecr:GetAuthorizationToken", "Resource": "*"},
    {"Effect": "Allow", "Action": ["ecr:BatchCheckLayerAvailability","ecr:InitiateLayerUpload","ecr:UploadLayerPart","ecr:CompleteLayerUpload","ecr:PutImage","ecr:BatchGetImage"], "Resource": "arn:aws:ecr:eu-central-1:$ACCOUNT_ID:repository/spry-backend"},
    {"Effect": "Allow", "Action": ["ecs:DescribeTaskDefinition","ecs:RegisterTaskDefinition","ecs:UpdateService","ecs:DescribeServices"], "Resource": "*"},
    {"Effect": "Allow", "Action": "iam:PassRole", "Resource": "arn:aws:iam::$ACCOUNT_ID:role/ecsTaskExecutionRole"},
    {"Effect": "Allow", "Action": "s3:ListBucket", "Resource": "arn:aws:s3:::$FRONTEND_BUCKET"},
    {"Effect": "Allow", "Action": ["s3:PutObject","s3:DeleteObject"], "Resource": "arn:aws:s3:::$FRONTEND_BUCKET/*"},
    {"Effect": "Allow", "Action": "cloudfront:CreateInvalidation", "Resource": "arn:aws:cloudfront::$ACCOUNT_ID:distribution/E21I2RKF628XEZ"}
  ]
}
EOF

aws iam create-role --role-name spry-github-deploy --assume-role-policy-document file:///tmp/trust.json >/dev/null 2>&1 \
  || aws iam update-assume-role-policy --role-name spry-github-deploy --policy-document file:///tmp/trust.json
aws iam put-role-policy --role-name spry-github-deploy --policy-name deploy --policy-document file:///tmp/perm.json
echo "DONE. Role: arn:aws:iam::$ACCOUNT_ID:role/spry-github-deploy"