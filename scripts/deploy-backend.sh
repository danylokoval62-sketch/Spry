#!/usr/bin/env bash
set -euo pipefail
IMAGE="$1"
TD=$(aws ecs describe-task-definition --task-definition spry-backend-task --query taskDefinition)
NEW=$(echo "$TD" | jq --arg IMG "$IMAGE" 'del(.taskDefinitionArn,.revision,.status,.requiresAttributes,.compatibilities,.registeredAt,.registeredBy) | .containerDefinitions[0].image = $IMG')
ARN=$(aws ecs register-task-definition --cli-input-json "$NEW" --query taskDefinition.taskDefinitionArn --output text)
aws ecs update-service --cluster spry-cluster --service spry-backend-service --task-definition "$ARN" > /dev/null
aws ecs wait services-stable --cluster spry-cluster --services spry-backend-service