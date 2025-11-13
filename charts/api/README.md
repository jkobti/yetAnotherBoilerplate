# YetAnotherBoilerplate API Helm Chart

Backend API service chart for the YetAnotherBoilerplate project. Deployable to local Kubernetes (kind) and cloud clusters (GKE, EKS, etc.).

## Quick Start

### Local Deployment (kind cluster)

```bash
# Build the API image locally
make build-api

# Create and start a local kind cluster
make kind-up

# Deploy the API chart
make deploy-local

# Check deployment status
kubectl get pods -n apps
kubectl logs -n apps -l app.kubernetes.io/name=api
```

### Manual Helm Install

```bash
# Dry-run to validate
helm install yab-api charts/api \
  --namespace apps \
  --dry-run --debug

# Actual install
helm install yab-api charts/api \
  --namespace apps \
  --set image.repository=yetanotherboilerplate/api \
  --set image.tag=dev \
  --set image.pullPolicy=Never
```

## Configuration

All values are defined in `values.yaml`. Key configurable parameters:

### Deployment

| Parameter          | Default                     | Description                                                     |
| ------------------ | --------------------------- | --------------------------------------------------------------- |
| `enabled`          | `true`                      | Enable/disable entire chart (all resources gated by this)       |
| `replicaCount`     | `1`                         | Number of API pod replicas                                      |
| `image.repository` | `yetanotherboilerplate/api` | Docker image repository                                         |
| `image.tag`        | `dev`                       | Image tag or SHA                                                |
| `image.pullPolicy` | `IfNotPresent`              | Image pull policy (IfNotPresent for local, Always for registry) |

### Resources

| Parameter                   | Default | Description            |
| --------------------------- | ------- | ---------------------- |
| `resources.requests.cpu`    | `100m`  | CPU request per pod    |
| `resources.requests.memory` | `128Mi` | Memory request per pod |
| `resources.limits.cpu`      | `500m`  | CPU limit per pod      |
| `resources.limits.memory`   | `512Mi` | Memory limit per pod   |

### Service

| Parameter      | Default     | Description                                         |
| -------------- | ----------- | --------------------------------------------------- |
| `service.type` | `ClusterIP` | Kubernetes service type                             |
| `service.port` | `8000`      | Internal service port (maps to container port 8000) |

### Ingress (disabled by default)

| Parameter                        | Default         | Description                                       |
| -------------------------------- | --------------- | ------------------------------------------------- |
| `ingress.enabled`                | `false`         | Enable ingress (set to true for external routing) |
| `ingress.className`              | `nginx`         | Ingress class (requires NGINX controller)         |
| `ingress.hosts[0].host`          | `api.local.dev` | Ingress hostname                                  |
| `ingress.hosts[0].paths[0].path` | `/`             | Path prefix                                       |

### Autoscaling (disabled by default)

| Parameter                                    | Default | Description                          |
| -------------------------------------------- | ------- | ------------------------------------ |
| `autoscaling.enabled`                        | `false` | Enable Horizontal Pod Autoscaler     |
| `autoscaling.minReplicas`                    | `1`     | Minimum replicas                     |
| `autoscaling.maxReplicas`                    | `3`     | Maximum replicas                     |
| `autoscaling.targetCPUUtilizationPercentage` | `70`    | Target CPU utilization % for scaling |

## Examples

### Enable Ingress

```bash
helm install yab-api charts/api \
  --namespace apps \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=api.example.com
```

### Enable Autoscaling

```bash
helm install yab-api charts/api \
  --namespace apps \
  --set autoscaling.enabled=true \
  --set autoscaling.minReplicas=2 \
  --set autoscaling.maxReplicas=10
```

### Use Custom Values File

```bash
helm install yab-api charts/api \
  --namespace apps \
  --values custom-values.yaml
```

## Health Checks

The deployment includes:
- **Liveness Probe**: HTTP GET `/health/` every 30s (initial delay 10s)
- **Readiness Probe**: HTTP GET `/health/` every 10s (initial delay 5s)

Ensure your API backend responds with `200 OK` on the `/health/` endpoint.

## Cleanup

```bash
# Uninstall the Helm release
helm uninstall yab-api -n apps

# Destroy the local cluster
make kind-down
```

## Notes

- **Local development**: Use `image.pullPolicy=Never` and build images locally with `make build-api`.
- **Registry deployment**: Set `image.repository` to your registry (e.g., `ghcr.io/jkobti/...`) and `image.pullPolicy=Always`.
- **Namespace isolation**: The chart deploys to the `apps` namespace (create via `k8s/base/namespaces.yaml` first).
- **Disabled by default**: Ingress and autoscaling are intentionally disabled initially; enable as needed.

## Troubleshooting

### Pod stuck in CrashLoopBackOff

Check logs:
```bash
kubectl logs -n apps -l app.kubernetes.io/name=api --tail=50
```

Common issues:
- Missing environment variables (DATABASE_URL, etc.) — check ConfigMap/Secret binding
- Image not found — verify image.pullPolicy matches your setup
- Health check failures — ensure `/health` endpoint returns 200 OK

### Port Access

For local development without ingress, use port-forward:
```bash
kubectl port-forward -n apps svc/api-api 8000:8000
# Access API at http://localhost:8000
```
