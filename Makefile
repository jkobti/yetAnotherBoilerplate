.PHONY: help build-api build-web build-admin helm-template-api helm-template-web helm-template-admin load-images kind-up kind-down deploy-local deploy-web deploy-admin install-nginx deploy-ingress setup-local-dns create-secrets create-secrets-from-env create-secrets-old apply-network-policies cluster-delete

help:
	@echo "Available targets:"
	@echo "  build-api              Build backend API Docker image locally"
	@echo "  build-web              Build web frontend Docker image locally"
	@echo "  build-admin            Build admin frontend Docker image locally"
	@echo "  helm-template-api      Render API Helm chart templates"
	@echo "  helm-template-web      Render web Helm chart templates"
	@echo "  helm-template-admin    Render admin Helm chart templates"
	@echo "  load-images            Load Docker images into kind cluster"
	@echo "  kind-up                Create local kind cluster"
	@echo "  kind-down              Destroy local kind cluster"
	@echo "  cluster-delete         Delete entire cluster and clean up (kind cluster + Docker images + state)"
	@echo "  deploy-local           Deploy API chart to local kind cluster"
	@echo "  deploy-web             Deploy web chart to local kind cluster"
	@echo "  deploy-admin           Deploy admin chart to local kind cluster"
	@echo "  install-nginx          Install NGINX ingress controller to kind cluster"
	@echo "  deploy-ingress         Enable ingress on API chart and deploy"
	@echo "  setup-local-dns        Add *.local.dev entries to /etc/hosts (requires sudo)"
	@echo "  create-secrets         Create Kubernetes Secrets from .env.k8s file"
	@echo "  create-secrets-from-env Create Kubernetes Secrets from env file (specify ENV_FILE)"
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

# Load Docker images into kind cluster
load-images:
	@echo "Loading Docker images into kind cluster..."
	kind load docker-image yetanotherboilerplate/api:dev --name yab-local
	kind load docker-image yetanotherboilerplate/web:dev --name yab-local
	kind load docker-image yetanotherboilerplate/admin:dev --name yab-local
	@echo "✓ Images loaded into kind cluster"

# Create a local kind cluster
kind-up:
	@echo "Creating local kind cluster..."
	kind create cluster --config k8s/kind-config.yaml --name yab-local
	@echo "Loading Docker images into kind cluster..."
	@kind load docker-image yetanotherboilerplate/api:dev --name yab-local 2>/dev/null || echo "  (api:dev image not yet built)"
	@kind load docker-image yetanotherboilerplate/web:dev --name yab-local 2>/dev/null || echo "  (web:dev image not yet built)"
	@kind load docker-image yetanotherboilerplate/admin:dev --name yab-local 2>/dev/null || echo "  (admin:dev image not yet built)"

# Destroy the local kind cluster
kind-down:
	@echo "Destroying local kind cluster..."
	kind delete cluster --name yab-local

# Delete entire cluster and clean up (comprehensive reset)
cluster-delete:
	@echo "Starting comprehensive cluster deletion..."
	@echo ""
	@echo "Step 1: Deleting kind cluster..."
	@kind delete cluster --name yab-local 2>/dev/null || echo "  - kind cluster not found (already deleted or doesn't exist)"
	@echo "  - kind cluster deleted"
	@echo ""
	@echo "Step 2: Cleaning up Docker port bindings..."
	@echo "  - Waiting for Docker to release ports (this may take a few seconds)..."
	@sleep 3
	@docker container prune -f >/dev/null 2>&1 || true
	@echo "  - Port bindings cleaned"
	@echo ""
	@echo "Step 3: Removing Docker images..."
	@docker rmi -f yetanotherboilerplate/api:dev 2>/dev/null || echo "  - api:dev image not found"
	@docker rmi -f yetanotherboilerplate/web:dev 2>/dev/null || echo "  - web:dev image not found"
	@docker rmi -f yetanotherboilerplate/admin:dev 2>/dev/null || echo "  - admin:dev image not found"
	@echo "  - Docker images removed"
	@echo ""
	@echo "Step 4: Cleaning up kubeconfig..."
	@kubectl config delete-context kind-yab-local 2>/dev/null || echo "  - kind context not found"
	@echo "  - kubeconfig cleaned"
	@echo ""
	@echo "Step 5: Removing backend database file..."
	@rm -f packages/backend/db.sqlite3 2>/dev/null || echo "  - database file not found"
	@echo "  - database file removed"
	@echo ""
	@echo "Cluster deletion complete! You can now run 'make kind-up' to create a fresh cluster."

# Deploy API chart to local cluster (assumes namespaces exist)
deploy-local: build-api
	@echo "Deploying namespaces..."
	kubectl apply -f k8s/base/namespaces.yaml
	@echo "Deploying service accounts..."
	kubectl apply -f k8s/base/serviceaccounts.yaml
	@echo "Deploying PostgreSQL database to 'apps' namespace..."
	helm install postgres charts/postgres \
		--namespace apps \
		-f k8s/values/local/postgres.yaml \
		2>/dev/null || helm upgrade postgres charts/postgres \
		--namespace apps \
		-f k8s/values/local/postgres.yaml
	@echo "Waiting for PostgreSQL to be ready..."
	kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgres -n apps --timeout=120s
	@echo "Deploying API chart to 'apps' namespace..."
	helm install yab-api charts/api \
		--namespace apps \
		-f k8s/values/local/api.yaml \
		--set image.repository=yetanotherboilerplate/api \
		--set image.tag=dev \
		--set image.pullPolicy=Never \
		2>/dev/null || helm upgrade yab-api charts/api \
		--namespace apps \
		-f k8s/values/local/api.yaml \
		--set image.repository=yetanotherboilerplate/api \
		--set image.tag=dev \
		--set image.pullPolicy=Never
	@echo "✓ API deployed. Check status with: kubectl get pods -n apps"
	@echo ""
	@echo "IMPORTANT: If the API pod is in a pending state, run:"
	@echo "  make create-secrets"
	@echo ""
	@echo "This creates the 'api-env' secret required for Django migrations in the init container."
	@echo "See packages/backend/.env.k8s.example for the environment variables to configure."

# Deploy web chart to local cluster
deploy-web: build-web
	@echo "Deploying namespaces..."
	kubectl apply -f k8s/base/namespaces.yaml
	@echo "Deploying service accounts..."
	kubectl apply -f k8s/base/serviceaccounts.yaml
	@echo "Deploying web chart to 'apps' namespace..."
	helm install yab-web charts/web \
		--namespace apps \
		--set enabled=true \
		--set image.repository=yetanotherboilerplate/web \
		--set image.tag=dev \
		--set image.pullPolicy=Never \
		2>/dev/null || helm upgrade yab-web charts/web \
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
	@echo "Deploying service accounts..."
	kubectl apply -f k8s/base/serviceaccounts.yaml
	@echo "Deploying admin chart to 'apps' namespace..."
	helm install yab-admin charts/admin \
		--namespace apps \
		--set enabled=true \
		--set image.repository=yetanotherboilerplate/admin \
		--set image.tag=dev \
		--set image.pullPolicy=Never \
		2>/dev/null || helm upgrade yab-admin charts/admin \
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

# Create Kubernetes Secrets from environment file
# Usage: make create-secrets-from-env [ENV_FILE=path/to/file]
# Default: packages/backend/.env.k8s
create-secrets-from-env:
	@if [ ! -f "packages/backend/.env.k8s" ]; then \
		echo "Error: packages/backend/.env.k8s not found. Copy the template first:"; \
		echo "  cp packages/backend/.env.k8s.example packages/backend/.env.k8s"; \
		echo "  # Edit and add your values"; \
		echo "  make create-secrets"; \
		exit 1; \
	fi; \
	echo "Creating api-env Secret from packages/backend/.env.k8s..."; \
	kubectl create secret generic api-env \
		--from-env-file=packages/backend/.env.k8s \
		-n apps \
		--dry-run=client -o yaml | kubectl apply -f -; \
	echo "✓ api-env Secret created/updated"

# Create Kubernetes Secrets for local development (from env file)
# Alias for create-secrets-from-env with default path
create-secrets: create-secrets-from-env

# Create Kubernetes Secrets with hardcoded values (deprecated, for backwards compatibility)
create-secrets-old:
	@echo "WARNING: This target uses hardcoded values. Prefer 'make create-secrets' instead."
	@echo "Creating api-env Secret in apps namespace..."
	@echo "Note: Edit packages/backend/.env.k8s and run 'make create-secrets' for proper local setup."
	kubectl create secret generic api-env \
		--from-literal=DATABASE_URL="sqlite:///db.sqlite3" \
		--from-literal=REDIS_URL="redis://localhost:6379/0" \
		--from-literal=JWT_SECRET="dev-secret-key-change-in-prod" \
		--from-literal=LOG_LEVEL="info" \
		--from-literal=DEBUG="true" \
		--from-literal=SECRET_KEY="dev-insecure-secret-key" \
		--from-literal=ALLOWED_HOSTS="127.0.0.1,localhost,0.0.0.0,api.local.dev" \
		--from-literal=API_DOCS_ENABLED="true" \
		--from-literal=EMAIL_PROVIDER="console" \
		--from-literal=DEFAULT_FROM_EMAIL="no-reply@example.local" \
		--from-literal=CORS_ALLOW_ALL_ORIGINS="true" \
		--from-literal=MAGIC_LINK_VERIFY_URL="http://localhost:5173" \
		--from-literal=MAGIC_LINK_EXPIRY_MINUTES="5" \
		--from-literal=MAGIC_LINK_DEBUG_ECHO_TOKEN="true" \
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
