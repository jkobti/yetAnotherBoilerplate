.PHONY: help build-api helm-template-api kind-up kind-down deploy-local

help:
	@echo "Available targets:"
	@echo "  build-api              Build backend API Docker image locally"
	@echo "  helm-template-api      Render API Helm chart templates"
	@echo "  kind-up                Create local kind cluster"
	@echo "  kind-down              Destroy local kind cluster"
	@echo "  deploy-local           Deploy API chart to local kind cluster"

# Build backend API image
build-api:
	@echo "Building backend API image..."
	docker build -f packages/backend/Dockerfile -t yetanotherboilerplate/api:dev packages/backend

# Template the API Helm chart
helm-template-api:
	@echo "Rendering API Helm chart..."
	helm template yab-api charts/api

# Create a local kind cluster
kind-up:
	@echo "Creating local kind cluster..."
	kind create cluster --config k8s/kind-config.yaml --name yab-local

# Destroy the local kind cluster
kind-down:
	@echo "Destroying local kind cluster..."
	kind delete cluster --name yab-local

# Deploy API chart to local cluster (assumes namespaces exist)
deploy-local: build-api
	@echo "Deploying namespaces..."
	kubectl apply -f k8s/base/namespaces.yaml
	@echo "Deploying API chart to 'apps' namespace..."
	helm install yab-api charts/api \
		--namespace apps \
		--set image.repository=yetanotherboilerplate/api \
		--set image.tag=dev \
		--set image.pullPolicy=Never
	@echo "✓ API deployed. Check status with: kubectl get pods -n apps"
