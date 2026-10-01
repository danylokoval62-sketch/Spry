#!/usr/bin/env bash
set -euo pipefail
export AWS_PROFILE=new AWS_REGION=eu-central-1 AWS_DEFAULT_REGION=eu-central-1 AWS_PAGER=""

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
[ "$ACCOUNT_ID" = "649089875356" ] || { echo "WRONG ACCOUNT: $ACCOUNT_ID"; exit 1; }

aws ecr create-repository --repository-name spry-backend >/dev/null 2>&1 || echo "ecr exists"
aws ecs create-cluster --cluster-name spry-cluster >/dev/null
aws logs create-log-group --log-group-name /ecs/spry-backend 2>/dev/null || echo "log group exists"

VPC_ID=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
read SUBNET_A SUBNET_B <<< "$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID --query 'Subnets[0:2].SubnetId' --output text)"

ALB_SG=$(aws ec2 create-security-group --group-name spry-alb-sg --description alb --vpc-id "$VPC_ID" --query GroupId --output text)
ECS_SG=$(aws ec2 create-security-group --group-name spry-ecs-sg --description ecs --vpc-id "$VPC_ID" --query GroupId --output text)
RDS_SG=$(aws ec2 create-security-group --group-name spry-rds-sg --description rds --vpc-id "$VPC_ID" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$ALB_SG" --protocol tcp --port 80 --cidr 0.0.0.0/0 >/dev/null
aws ec2 authorize-security-group-ingress --group-id "$ALB_SG" --protocol tcp --port 443 --cidr 0.0.0.0/0 >/dev/null
aws ec2 authorize-security-group-ingress --group-id "$ECS_SG" --protocol tcp --port 8000 --source-group "$ALB_SG" >/dev/null
aws ec2 authorize-security-group-ingress --group-id "$RDS_SG" --protocol tcp --port 5432 --source-group "$ECS_SG" >/dev/null

cat > infra/aws-ids.env <<EOF
VPC_ID=$VPC_ID
SUBNET_A=$SUBNET_A
SUBNET_B=$SUBNET_B
ALB_SG=$ALB_SG
ECS_SG=$ECS_SG
RDS_SG=$RDS_SG
EOF

aws iam create-role --role-name ecsTaskExecutionRole --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}' >/dev/null 2>&1 || echo "role exists"
aws iam attach-role-policy --role-name ecsTaskExecutionRole --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
aws iam put-role-policy --role-name ecsTaskExecutionRole --policy-name spry-ssm-read --policy-document "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"ssm:GetParameters\",\"Resource\":\"arn:aws:ssm:eu-central-1:$ACCOUNT_ID:parameter/spry/*\"}]}"

aws rds create-db-subnet-group --db-subnet-group-name spry-subnets --db-subnet-group-description spry --subnet-ids "$SUBNET_A" "$SUBNET_B" >/dev/null
DB_PASS=$(openssl rand -hex 16)
aws rds create-db-instance --db-instance-identifier spry-db --engine postgres --engine-version 16 --db-instance-class db.t3.micro --allocated-storage 20 --master-username spry --master-user-password "$DB_PASS" --db-name spry --vpc-security-group-ids "$RDS_SG" --db-subnet-group-name spry-subnets --no-publicly-accessible --backup-retention-period 0 >/dev/null
echo "Waiting for RDS (5-10 min)..."
aws rds wait db-instance-available --db-instance-identifier spry-db
DB_HOST=$(aws rds describe-db-instances --db-instance-identifier spry-db --query 'DBInstances[0].Endpoint.Address' --output text)
aws ssm put-parameter --name /spry/DATABASE_URL --type SecureString --overwrite --value "postgresql+psycopg://spry:$DB_PASS@$DB_HOST:5432/spry?sslmode=require" >/dev/null
echo "DONE. Host: $DB_HOST"