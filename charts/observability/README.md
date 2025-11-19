# Observability Chart

This chart deploys the observability stack for YetAnotherBoilerplate, wrapping `kube-prometheus-stack`.

## Components

- **Prometheus**: Metrics collection and storage.
- **Grafana**: Visualization and dashboards.
- **Alertmanager**: Alert handling.

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
