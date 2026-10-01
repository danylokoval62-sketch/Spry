AWS_REGION ?= eu-central-1
IMAGE_TAG ?= $(shell git rev-parse --short HEAD)
ECR_REPOSITORY ?= spry-backend
ECS_CLUSTER ?= spry-cluster
ECS_SERVICE ?= spry-backend-service
S3_BUCKET ?= spry-frontend-bucket
CLOUDFRONT_DISTRIBUTION_ID ?= your-dist-id

ECR_REGISTRY ?= $(shell aws sts get-caller-identity --query Account --output text).dkr.ecr.$(AWS_REGION).amazonaws.com
BACKEND_IMAGE = $(ECR_REGISTRY)/$(ECR_REPOSITORY):$(IMAGE_TAG)

.PHONY: lint-backend build-frontend deploy-frontend deploy-backend

lint-backend:
	ruff check backend/

build-frontend:
	npm --prefix frontend run build

deploy-frontend: build-frontend
	aws s3 sync frontend/dist/ s3://$(S3_BUCKET) --delete
	aws cloudfront create-invalidation --distribution-id $(CLOUDFRONT_DISTRIBUTION_ID) --paths "/*"

deploy-backend:
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(ECR_REGISTRY)
	docker build -t $(BACKEND_IMAGE) backend/
	docker push $(BACKEND_IMAGE)
	aws ecs update-service --cluster $(ECS_CLUSTER) --service $(ECS_SERVICE) --force-new-deployment
