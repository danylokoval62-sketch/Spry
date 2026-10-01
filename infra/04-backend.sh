#!/usr/bin/env bash
set -euo pipefail
export AWS_PROFILE=new AWS_REGION=eu-central-1 AWS_DEFAULT_REGION=eu-central-1 AWS_PAGER=""
source infra/aws-ids.env

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
[ "$ACCOUNT_ID" = "649089875356" ] || { echo "WRONG ACCOUNT: $ACCOUNT_ID"; exit 1; }
export ACCOUNT_ID TAG

echo "Waiting for api certificate..."
aws acm wait certificate-validated --certificate-arn "$API_CERT"

python3 - <<'PY'
import json, os
acc, tag = os.environ["ACCOUNT_ID"], os.environ["TAG"]
td = {
  "family": "spry-backend-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256", "memory": "512",
  "runtimePlatform": {"cpuArchitecture": "X86_64", "operatingSystemFamily": "LINUX"},
  "executionRoleArn": f"arn:aws:iam::{acc}:role/ecsTaskExecutionRole",
  "containerDefinitions": [{
    "name": "spry-backend",
    "image": f"{acc}.dkr.ecr.eu-central-1.amazonaws.com/spry-backend:{tag}",
    "essential": True,
    "portMappings": [{"containerPort": 8000, "protocol": "tcp"}],
    "environment": [{"name": "CORS_ORIGINS", "value": "https://app.spry-koval.me"}],
    "secrets": [{"name": "DATABASE_URL", "valueFrom": f"arn:aws:ssm:eu-central-1:{acc}:parameter/spry/DATABASE_URL"}],
    "logConfiguration": {"logDriver": "awslogs", "options": {
      "awslogs-group": "/ecs/spry-backend", "awslogs-region": "eu-central-1", "awslogs-stream-prefix": "ecs"}}
  }]
}
json.dump(td, open("infra/task-def.json", "w"), indent=2)
PY

TD_ARN=$(aws ecs register-task-definition --cli-input-json file://infra/task-def.json --query taskDefinition.taskDefinitionArn --output text)
echo "Task definition: $TD_ARN"

ALB_ARN=$(aws elbv2 create-load-balancer --name spry-alb --subnets "$SUBNET_A" "$SUBNET_B" --security-groups "$ALB_SG" --query 'LoadBalancers[0].LoadBalancerArn' --output text)
ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --query 'LoadBalancers[0].DNSName' --output text)
TG_ARN=$(aws elbv2 create-target-group --name spry-tg --protocol HTTP --port 8000 --vpc-id "$VPC_ID" --target-type ip --health-check-path /health --query 'TargetGroups[0].TargetGroupArn' --output text)

aws elbv2 create-listener --load-balancer-arn "$ALB_ARN" --protocol HTTPS --port 443 --certificates CertificateArn="$API_CERT" --default-actions Type=forward,TargetGroupArn="$TG_ARN" >/dev/null
aws elbv2 create-listener --load-balancer-arn "$ALB_ARN" --protocol HTTP --port 80 --default-actions 'Type=redirect,RedirectConfig={Protocol=HTTPS,Port=443,StatusCode=HTTP_301}' >/dev/null

aws ecs create-service --cluster spry-cluster --service-name spry-backend-service --task-definition "$TD_ARN" --desired-count 1 --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_A,$SUBNET_B],securityGroups=[$ECS_SG],assignPublicIp=ENABLED}" \
  --load-balancers targetGroupArn="$TG_ARN",containerName=spry-backend,containerPort=8000 \
  --health-check-grace-period-seconds 90 >/dev/null

echo "ALB_DNS=$ALB_DNS" >> infra/aws-ids.env
echo "TG_ARN=$TG_ARN" >> infra/aws-ids.env
echo "DONE. ALB: $ALB_DNS"