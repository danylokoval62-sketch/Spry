AWS_REGION      ?= eu-central-1
ACCOUNT_ID      ?= 649089875356
REGISTRY        := $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
TAG             ?= $(shell git rev-parse HEAD)
IMAGE           := $(REGISTRY)/spry-backend:$(TAG)
FRONTEND_BUCKET ?= spry-koval-frontend-649089875356
CF_DIST_ID      ?= E21I2RKF628XEZ
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