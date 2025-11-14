.PHONY: help build-api build-web build-admin helm-template-api helm-template-web helm-template-admin kind-up kind-down deploy-local deploy-web deploy-admin install-nginx deploy-ingress setup-local-dns create-secrets apply-network-policies

help:
	@echo "Available targets:"
	@echo "  build-api              Build backend API Docker image locally"
	@echo "  build-web              Build web frontend Docker image locally"
	@echo "  build-admin            Build admin frontend Docker image locally"
	@echo "  helm-template-api      Render API Helm chart templates"
	@echo "  helm-template-web      Render web Helm chart templates"
	@echo "  helm-template-admin    Render admin Helm chart templates"
	@echo "  kind-up                Create local kind cluster"
	@echo "  kind-down              Destroy local kind cluster"
	@echo "  deploy-local           Deploy API chart to local kind cluster"
	@echo "  deploy-web             Deploy web chart to local kind cluster"
	@echo "  deploy-admin           Deploy admin chart to local kind cluster"
	@echo "  install-nginx          Install NGINX ingress controller to kind cluster"
	@echo "  deploy-ingress         Enable ingress on API chart and deploy"
	@echo "  setup-local-dns        Add *.local.dev entries to /etc/hosts (requires sudo)"
	@echo "  create-secrets         Create Kubernetes Secrets for local development"
	@echo "  apply-network-policies Apply NetworkPolicies to clusters"

# Build backend API image
build-api:
	@echo "Building backend API image..."
	docker build -f packages/backend/Dockerfile -t yetanotherboilerplate/api:dev packages/backend

# Build web frontend image (Flutter web → NGINX)
# Pass API_BASE_URL as build arg (default: http://localhost:8000 for local port-forward access)
# Use repo root as build context (.) so Dockerfile can reference monorepo paths
build-web:
	@echo "Building web frontend image..."
	@if [ -f packages/flutter_app/Dockerfile.web ]; then \
		docker build -f packages/flutter_app/Dockerfile.web \
			--build-arg API_BASE_URL="http://localhost:8000" \
			--build-arg PUSH_NOTIFICATIONS_ENABLED="false" \
			-t yetanotherboilerplate/web:dev .; \
	else \
		echo "Error: Dockerfile.web not found at packages/flutter_app/Dockerfile.web"; \
		exit 1; \
	fi

# Build admin frontend image (Flutter web → NGINX)
# Pass API_BASE_URL as build arg (default: http://localhost:8000 for local port-forward access)
# Use repo root as build context (.) so Dockerfile can reference monorepo paths
build-admin:
	@echo "Building admin frontend image..."
	@if [ -f packages/flutter_app/Dockerfile.admin.web ]; then \
		docker build -f packages/flutter_app/Dockerfile.admin.web \
			--build-arg API_BASE_URL="http://localhost:8000" \
			--build-arg PUSH_NOTIFICATIONS_ENABLED="false" \
			-t yetanotherboilerplate/admin:dev .; \
	else \
		echo "Error: Dockerfile.admin.web not found at packages/flutter_app/Dockerfile.admin.web"; \
		exit 1; \
	fi

# Template the API Helm chart
helm-template-api:
	@echo "Rendering API Helm chart..."
	helm template yab-api charts/api

# Template the web Helm chart
helm-template-web:
	@echo "Rendering web Helm chart..."
	helm template yab-web charts/web

# Template the admin Helm chart
helm-template-admin:
	@echo "Rendering admin Helm chart..."
	helm template yab-admin charts/admin

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

# Deploy web chart to local cluster
deploy-web: build-web
	@echo "Deploying namespaces..."
	kubectl apply -f k8s/base/namespaces.yaml
	@echo "Deploying web chart to 'apps' namespace..."
	helm install yab-web charts/web \
		--namespace apps \
		--set enabled=true \
		--set image.repository=yetanotherboilerplate/web \
		--set image.tag=dev \
		--set image.pullPolicy=Never
	@echo "✓ Web deployed. Check status with: kubectl get pods -n apps"

# Deploy admin chart to local cluster
deploy-admin: build-admin
	@echo "Deploying namespaces..."
	kubectl apply -f k8s/base/namespaces.yaml
	@echo "Deploying admin chart to 'apps' namespace..."
	helm install yab-admin charts/admin \
		--namespace apps \
		--set enabled=true \
		--set image.repository=yetanotherboilerplate/admin \
		--set image.tag=dev \
		--set image.pullPolicy=Never
	@echo "✓ Admin deployed. Check status with: kubectl get pods -n apps"

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
	@echo "Adding *.local.dev entries to /etc/hosts..."
	@if grep -q "api.local.dev" /etc/hosts; then \
		echo "✓ api.local.dev already in /etc/hosts"; \
	else \
		echo "127.0.0.1 api.local.dev" | sudo tee -a /etc/hosts > /dev/null; \
		echo "✓ Added api.local.dev to /etc/hosts"; \
	fi
	@if grep -q "app.local.dev" /etc/hosts; then \
		echo "✓ app.local.dev already in /etc/hosts"; \
	else \
		echo "127.0.0.1 app.local.dev" | sudo tee -a /etc/hosts > /dev/null; \
		echo "✓ Added app.local.dev to /etc/hosts"; \
	fi
	@if grep -q "admin.local.dev" /etc/hosts; then \
		echo "✓ admin.local.dev already in /etc/hosts"; \
	else \
		echo "127.0.0.1 admin.local.dev" | sudo tee -a /etc/hosts > /dev/null; \
		echo "✓ Added admin.local.dev to /etc/hosts"; \
	fi

# Create Kubernetes Secrets for local development
# Edit the values below before running, or set as environment variables.
create-secrets:
	@echo "Creating api-env Secret in apps namespace..."
	@echo "Note: Update DATABASE_URL, REDIS_URL, and other values as needed."
	kubectl create secret generic api-env \
		--from-literal=DATABASE_URL="sqlite:///db.sqlite3" \
		--from-literal=REDIS_URL="redis://localhost:6379/0" \
		--from-literal=JWT_SECRET="dev-secret-key-change-in-prod" \
		--from-literal=LOG_LEVEL="info" \
		-n apps \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "✓ api-env Secret created/updated."
	@echo "Creating web-env Secret in apps namespace..."
	kubectl create secret generic web-env \
		--from-literal=API_URL="http://api.local.dev" \
		--from-literal=DEBUG="false" \
		-n apps \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "✓ web-env Secret created/updated."
	@echo "Creating admin-env Secret in apps namespace..."
	kubectl create secret generic admin-env \
		--from-literal=API_URL="http://api.local.dev" \
		--from-literal=DEBUG="false" \
		-n apps \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "✓ admin-env Secret created/updated."

# Apply NetworkPolicies to local cluster
# Note: Requires CNI plugin supporting NetworkPolicies (e.g., Calico).
apply-network-policies:
	@echo "Applying base ServiceAccounts..."
	kubectl apply -f k8s/base/serviceaccounts.yaml
	@echo "Applying NetworkPolicies..."
	kubectl apply -f k8s/base/network-policies/
	@echo "✓ NetworkPolicies applied. Verify with: kubectl get networkpolicies -n apps"
