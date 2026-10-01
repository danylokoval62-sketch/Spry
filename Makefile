AWS_REGION      ?= eu-north-1
ACCOUNT_ID      ?= 416121583967
REGISTRY        := $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
TAG             ?= $(shell git rev-parse HEAD)
IMAGE           := $(REGISTRY)/spry-backend:$(TAG)
FRONTEND_BUCKET ?= spry-koval-frontend
CF_DIST_ID      ?= E1ZL2OOHJRFU2S
API_URL         ?= https://api.spry-koval.me

lint:
	cd backend && ruff check .
	cd frontend && npm run lint && npx prettier --check .

deploy-backend:
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(REGISTRY)
	docker build --platform linux/amd64 -t $(IMAGE) backend
	docker push $(IMAGE)
	./scripts/deploy-backend.sh $(IMAGE)

deploy-frontend:
	cd frontend && npm ci && VITE_API_URL=$(API_URL) npm run build
	aws s3 sync frontend/dist s3://$(FRONTEND_BUCKET) --delete
	aws cloudfront create-invalidation --distribution-id $(CF_DIST_ID) --paths "/*"