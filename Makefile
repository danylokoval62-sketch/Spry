AWS_REGION      ?= eu-central-1
ACCOUNT_ID      ?= 649089875356
REGISTRY        := $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
TAG             ?= $(shell git rev-parse HEAD)
IMAGE           := $(REGISTRY)/spry-backend:$(TAG)
FRONTEND_BUCKET ?= spry-koval-frontend-649089875356
CF_DIST_ID      ?= E21I2RKF628XEZ
API_URL         ?= https://api.spry-koval.me
AUTH_STACK      ?= spry-auth
REPORTS_STACK   ?= spry-reports
AI_STACK        ?= spry-ai

-include .env
ai_out = $(shell aws cloudformation describe-stacks --region $(AWS_REGION) --stack-name $(AI_STACK) --query "Stacks[0].Outputs[?OutputKey=='$(1)'].OutputValue" --output text)
reports_out = $(shell aws cloudformation describe-stacks --region $(AWS_REGION) --stack-name $(REPORTS_STACK) --query "Stacks[0].Outputs[?OutputKey=='$(1)'].OutputValue" --output text)
auth_out = $(shell aws cloudformation describe-stacks --region us-east-1 --stack-name $(AUTH_STACK) --query "Stacks[0].Outputs[?OutputKey=='$(1)'].OutputValue" --output text)

lint:
	cd backend && ruff check .
	cd frontend && npm run lint && npx prettier --check .

push-image:
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(REGISTRY)
	docker build --platform linux/amd64 --provenance=false -t $(IMAGE) backend
	docker push $(IMAGE)

deploy-backend: push-image
	./scripts/deploy-backend.sh $(IMAGE)

deploy-frontend:
	cd frontend && npm ci && VITE_API_URL=$(API_URL) \
	  VITE_COGNITO_AUTHORITY=$(call auth_out,Authority) \
	  VITE_COGNITO_CLIENT_ID=$(call auth_out,ClientId) \
	  VITE_COGNITO_DOMAIN=$(call auth_out,Domain) \
	  VITE_PARSER_URL=$(call ai_out,ParserUrl) \
	  npm run build
	aws s3 sync frontend/dist s3://$(FRONTEND_BUCKET) --delete
	aws cloudfront create-invalidation --distribution-id $(CF_DIST_ID) --paths "/*"

deploy-auth:
	@aws cloudformation deploy --region us-east-1 --stack-name $(AUTH_STACK) \
	  --template-file infra/auth.yml --tags PROJECT_NAME=spry \
	  --parameter-overrides GoogleClientId=$(GOOGLE_CLIENT_ID) GoogleClientSecret=$(GOOGLE_CLIENT_SECRET)

# Weekly report (infra/reports.yml). Needs REPORT_RECIPIENT, e.g. in .env.
# Always passed, so a test run (SCHEDULE="rate(5 minutes)", FAIL_WEEK=2026-W39) does not stick.
SCHEDULE  ?= cron(0 7 ? * MON *)
FAIL_WEEK ?=
deploy-reports: push-image
	@. infra/aws-ids.env && aws cloudformation deploy --region $(AWS_REGION) --stack-name $(REPORTS_STACK) \
	  --template-file infra/reports.yml --tags PROJECT_NAME=spry --capabilities CAPABILITY_IAM \
	  --parameter-overrides ImageUri=$(IMAGE) VpcId=$$VPC_ID SubnetIds=$$SUBNET_A,$$SUBNET_B SecurityGroupId=$$ECS_SG \
	    RouteTableIds=$$(aws ec2 describe-route-tables --region $(AWS_REGION) --filters Name=vpc-id,Values=$$VPC_ID --query 'RouteTables[].RouteTableId' --output text | tr '\t' ',') \
	    DatabaseUrl="$$(aws ssm get-parameter --region $(AWS_REGION) --name /spry/DATABASE_URL --with-decryption --query Parameter.Value --output text)" \
	    Recipients=$(REPORT_RECIPIENT) ScheduleExpression="$(SCHEDULE)" FailWeek="$(FAIL_WEEK)"

# make report-now WEEK=2026-W39 (no WEEK = previous week)
report-now:
	aws sqs send-message --region $(AWS_REGION) --queue-url $(call reports_out,QueueUrl) --message-body '{"week": "$(WEEK)"}'

# Agenda parser (infra/ai.yml). BUDGET_EMAIL in .env creates the $5 monthly budget alarm.
PARSER_MODEL ?= us.anthropic.claude-haiku-4-5-20251001-v1:0
export PARSER_MODEL
deploy-ai: push-image
	@aws cloudformation deploy --region $(AWS_REGION) --stack-name $(AI_STACK) \
	  --template-file infra/ai.yml --tags PROJECT_NAME=spry --capabilities CAPABILITY_IAM \
	  --parameter-overrides ImageUri=$(IMAGE) ParserModel=$(PARSER_MODEL) \
	    CognitoAuthority=$(call auth_out,Authority) CognitoClientId=$(call auth_out,ClientId) \
	    BudgetEmail="$(BUDGET_EMAIL)"

# Needs the backend deps (pip install -r backend/requirements.txt) and AWS credentials.
llm-hello:
	cd backend && python -m app.ai.hello

# make parse TEXT="Пн 10:00, синк по прайсингу, 45 хв. 1) ..."
parse:
	cd backend && python -m app.ai.agenda
