AWS_REGION      ?= eu-central-1
ACCOUNT_ID      ?= 649089875356
REGISTRY        := $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
TAG             ?= $(shell git rev-parse HEAD)
IMAGE           := $(REGISTRY)/spry-backend:$(TAG)
FRONTEND_BUCKET ?= spry-koval-frontend-649089875356
CF_DIST_ID      ?= E21I2RKF628XEZ
API_URL         ?= https://api.spry-koval.me

-include .env
tf_out = $(shell terraform -chdir=infra output -raw $(1))

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
	  VITE_COGNITO_AUTHORITY=$(call tf_out,authority) \
	  VITE_COGNITO_CLIENT_ID=$(call tf_out,client_id) \
	  VITE_COGNITO_DOMAIN=$(call tf_out,cognito_domain) \
	  VITE_PARSER_URL=$(call tf_out,parser_url) \
	  npm run build
	aws s3 sync frontend/dist s3://$(FRONTEND_BUCKET) --delete
	aws cloudfront create-invalidation --distribution-id $(CF_DIST_ID) --paths "/*"

# Infrastructure (infra/*.tf) is applied only by HCP Terraform, after a merge. Never run apply here.
infra-plan:
	cd infra && terraform fmt -check && terraform init -input=false && terraform validate && terraform plan

# Roll out a new image to the Lambdas. Terraform ignores image_uri, so this is the app pipeline's job.
deploy-reports: push-image
	aws lambda update-function-code --region $(AWS_REGION) --function-name spry-report-builder --image-uri $(IMAGE)

# make report-now WEEK=2026-W39 (no WEEK = previous week)
report-now:
	aws sqs send-message --region $(AWS_REGION) --queue-url $(call tf_out,queue_url) --message-body '{"week": "$(WEEK)"}'

# Agenda parser (infra/ai.tf).
deploy-ai: push-image
	aws lambda update-function-code --region $(AWS_REGION) --function-name spry-agenda-parser --image-uri $(IMAGE)

# Needs the backend deps (pip install -r backend/requirements.txt) and AWS credentials.
llm-hello:
	cd backend && python -m app.ai.hello

# make parse TEXT="Пн 10:00, синк по прайсингу, 45 хв. 1) ..."
parse:
	cd backend && python -m app.ai.agenda
