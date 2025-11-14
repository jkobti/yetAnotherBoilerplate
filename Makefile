.PHONY: help build-api helm-template-api kind-up kind-down deploy-local install-nginx deploy-ingress

help:
	@echo "Available targets:"
	@echo "  build-api              Build backend API Docker image locally"
	@echo "  helm-template-api      Render API Helm chart templates"
	@echo "  kind-up                Create local kind cluster"
	@echo "  kind-down              Destroy local kind cluster"
	@echo "  deploy-local           Deploy API chart to local kind cluster"
	@echo "  install-nginx          Install NGINX ingress controller to kind cluster"
	@echo "  deploy-ingress         Enable ingress on API chart and deploy"
	@echo "  setup-local-dns        Add api.local.dev to /etc/hosts (requires sudo)"

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

# Install NGINX ingress controller to local kind cluster
install-nginx:
	@echo "Adding NGINX Helm repository..."
	helm repo add nginx-stable https://helm.nginx.com/stable
	helm repo update
	@echo "Installing NGINX ingress controller to 'ingress' namespace..."
	helm install nginx-ingress nginx-stable/nginx-ingress \
		--namespace ingress \
		--create-namespace \
		--set controller.service.type=NodePort \
		--set controller.service.nodePorts.http=80 \
		--set controller.service.nodePorts.https=443
	@echo "✓ NGINX installed. Check status with: kubectl get pods -n ingress"

# Enable ingress on API chart and deploy
deploy-ingress:
	@echo "Enabling ingress on API chart..."
	helm upgrade yab-api charts/api \
		--namespace apps \
		--set ingress.enabled=true \
		--set ingress.className=nginx \
		--set ingress.hosts[0].host=api.local.dev \
		--set ingress.hosts[0].paths[0].path=/ \
		--set ingress.hosts[0].paths[0].pathType=Prefix
	@echo "✓ Ingress enabled. Access API at http://api.local.dev"
	@echo "  (Make sure /etc/hosts has: 127.0.0.1 api.local.dev)"

# Add local DNS entries (requires sudo)
setup-local-dns:
	@echo "Adding api.local.dev to /etc/hosts..."
	@if grep -q "api.local.dev" /etc/hosts; then \
		echo "✓ api.local.dev already in /etc/hosts"; \
	else \
		echo "127.0.0.1 api.local.dev" | sudo tee -a /etc/hosts > /dev/null; \
		echo "✓ Added api.local.dev to /etc/hosts"; \
	fi
