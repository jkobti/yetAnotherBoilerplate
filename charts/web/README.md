# YetAnotherBoilerplate Web Frontend Helm Chart

Customer-facing web frontend chart for the YetAnotherBoilerplate project. Deployable to local Kubernetes (kind) and cloud clusters (GKE, EKS, etc.).

## Quick Start

### Local Deployment (kind cluster)

```bash
# Build the web image locally (Flutter web build → NGINX)
make build-web

# Create and start a local kind cluster (if not already running)
make kind-up

# Deploy the web chart (currently disabled by default)
helm install yab-web charts/web \
  --namespace apps \
  --set enabled=true \
  --set image.repository=yetanotherboilerplate/web \
  --set image.tag=dev \
  --set image.pullPolicy=IfNotPresent

# Check deployment status
kubectl get pods -n apps -l app.kubernetes.io/name=web
kubectl logs -n apps -l app.kubernetes.io/name=web
```

### Manual Helm Install

```bash
# Dry-run to validate
helm install yab-web charts/web \
  --namespace apps \
  --set enabled=true \
  --dry-run --debug

# Actual install
helm install yab-web charts/web \
  --namespace apps \
  --set enabled=true \
  --set image.repository=yetanotherboilerplate/web \
  --set image.tag=dev \
  --set image.pullPolicy=IfNotPresent
```

## Configuration

All values are defined in `values.yaml`. Key configurable parameters:

### Deployment

| Parameter          | Default                     | Description                                                     |
| ------------------ | --------------------------- | --------------------------------------------------------------- |
| `enabled`          | `false`                     | Enable/disable entire chart (all resources gated by this)       |
| `replicaCount`     | `1`                         | Number of web pod replicas                                      |
| `image.repository` | `yetanotherboilerplate/web` | Docker image repository                                         |
| `image.tag`        | `dev`                       | Image tag or SHA                                                |
| `image.pullPolicy` | `IfNotPresent`              | Image pull policy (IfNotPresent for local, Always for registry) |

### Resources

| Parameter                   | Default | Description            |
| --------------------------- | ------- | ---------------------- |
| `resources.requests.cpu`    | `50m`   | CPU request per pod    |
| `resources.requests.memory` | `64Mi`  | Memory request per pod |
| `resources.limits.cpu`      | `200m`  | CPU limit per pod      |
| `resources.limits.memory`   | `256Mi` | Memory limit per pod   |

### Service

| Parameter      | Default     | Description                                       |
| -------------- | ----------- | ------------------------------------------------- |
| `service.type` | `ClusterIP` | Kubernetes service type                           |
| `service.port` | `80`        | Internal service port (maps to container port 80) |

### Ingress (disabled by default)

| Parameter                        | Default         | Description                                       |
| -------------------------------- | --------------- | ------------------------------------------------- |
| `ingress.enabled`                | `false`         | Enable ingress (set to true for external routing) |
| `ingress.className`              | `nginx`         | Ingress class (requires NGINX controller)         |
| `ingress.hosts[0].host`          | `app.local.dev` | Ingress hostname                                  |
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
helm install yab-web charts/web \
  --namespace apps \
  --set enabled=true \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=app.example.com
```

### Enable Autoscaling

```bash
helm install yab-web charts/web \
  --namespace apps \
  --set enabled=true \
  --set autoscaling.enabled=true \
  --set autoscaling.minReplicas=2 \
  --set autoscaling.maxReplicas=10
```

### Use Custom Values File

```bash
helm install yab-web charts/web \
  --namespace apps \
  --values custom-values.yaml
```

## Health Checks

The deployment includes:
- **Liveness Probe**: HTTP GET `/` every 30s (initial delay 10s)
- **Readiness Probe**: HTTP GET `/` every 10s (initial delay 5s)

Ensure your web frontend responds with `200 OK` on the root `/` path.

## Cleanup

```bash
# Uninstall the Helm release
helm uninstall yab-web -n apps

# Destroy the local cluster
make kind-down
```

## Notes

- **Local development**: Use `image.pullPolicy=IfNotPresent` and build images locally with `make build-web`.
- **Registry deployment**: Set `image.repository` to your registry (e.g., `ghcr.io/jkobti/...`) and `image.pullPolicy=Always`.
- **Namespace isolation**: The chart deploys to the `apps` namespace (create via `k8s/base/namespaces.yaml` first).
- **Disabled by default**: Chart is disabled by default (`enabled: false`); enable with `--set enabled=true`.
- **Static content**: Built with Flutter web builder → NGINX for efficient static file serving.

## Troubleshooting

### Pod stuck in CrashLoopBackOff

Check logs:
```bash
kubectl logs -n apps -l app.kubernetes.io/name=web --tail=50
```

Verify NGINX is properly configured and the built application is in `/usr/share/nginx/html/`.

### Ingress not routing traffic

Ensure NGINX ingress controller is installed:
```bash
make install-nginx
```
