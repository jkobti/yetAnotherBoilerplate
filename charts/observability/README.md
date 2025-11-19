# Observability Chart

This chart deploys the observability stack for YetAnotherBoilerplate, wrapping `kube-prometheus-stack`.

## Components

- **Prometheus**: Metrics collection and storage.
- **Grafana**: Visualization and dashboards.
- **Alertmanager**: Alert handling.
- **Loki**: Log aggregation system.
- **Promtail**: Log collector that ships logs to Loki.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+

## Installation

1. Add the Prometheus Community Helm repo:
   ```bash
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo update
   ```

2. Update dependencies:
   ```bash
   helm dependency update charts/observability
   ```

3. Install the chart:
   ```bash
   helm upgrade --install observability charts/observability \
     --namespace observability \
     --create-namespace \
     --values charts/observability/values.yaml
   ```

## Configuration

See `values.yaml` for configuration options. The chart inherits most values from `kube-prometheus-stack`.

## Storage & Persistence

### Metrics (Prometheus)
By default, Prometheus uses ephemeral storage. To persist metrics across pod restarts, enable persistence in `values.yaml`:
```yaml
prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi
```

### Logs (Loki)
By default, Loki is configured with `filesystem` storage, which saves logs to the pod's ephemeral disk. **Logs will be lost if the pod is deleted.**

For production, you should configure object storage (S3, GCS, Azure) in `values.yaml`:
```yaml
loki-stack:
  loki:
    storage:
      type: s3
      s3:
        s3: s3://<region>/<bucket>
```
