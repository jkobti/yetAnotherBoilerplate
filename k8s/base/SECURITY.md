# Security & Config Management (Phase 5)

This document outlines the security baseline and configuration strategy for the yetAnotherBoilerplate Kubernetes deployment.

## Overview

Phase 5 establishes least-privilege principles, secret management hygiene, and network isolation foundations. This is a living document updated as security posture evolves.

---

## 1. ServiceAccounts

All workload pods run under dedicated ServiceAccounts tied to their component. This enables future RBAC policies and pod identity federation.

### ServiceAccounts Defined

- **`api`** (namespace: `apps`)
  - Used by: API deployment pods
  - Future: Read-only access to ConfigMaps, Secrets (api-config, api-env)

- **`worker`** (namespace: `apps`)
  - Used by: Background task processor (deferred until queue system chosen)
  - Future: Read-only access to worker-env Secret, write to specific resources (e.g., job logs)

- **`observability`** (namespace: `observability`)
  - Used by: Prometheus, Grafana, log collectors
  - Future: Read access to pod metrics endpoints, logs across namespaces

### Enabling ServiceAccounts in Helm Charts

Update `charts/api/templates/deployment.yaml` to reference the ServiceAccount:

```yaml
spec:
  serviceAccountName: api  # Reference the ServiceAccount
  containers:
    - name: api
      ...
```

Similarly for worker and other components.

---

## 2. Secret Management Strategy

### Local Development (`kind` cluster)

**Mechanism**: Kubernetes Secrets (unencrypted in etcd, acceptable for local/ephemeral clusters)

**Workflow**:
1. Create Secret manually or via `make` target:
   ```bash
   kubectl create secret generic api-env \
     --from-literal=DATABASE_URL="postgres://..." \
     --from-literal=REDIS_URL="redis://..." \
     -n apps
   ```

2. Or define in version control (gitops, encrypted with SOPS or similar):
   ```yaml
   # k8s/overlays/local/secrets.yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: api-env
     namespace: apps
   type: Opaque
   data:
     DATABASE_URL: <base64-encoded>
     REDIS_URL: <base64-encoded>
   ```

3. Pod mounts as environment variables or files (see Deployment template).

### Staging & Production

**Mechanism**: SealedSecrets or External Secrets Operator

**Rationale**: etcd encryption alone insufficient; sealed/external secrets prevent accidental exposure in version control.

**Future Roadmap**:
- [ ] Install Sealed Secrets controller or ESO
- [ ] Encrypt sensitive values at rest
- [ ] Integrate with external secret backend (AWS Secrets Manager, HashiCorp Vault, etc.)
- [ ] Document rotation and audit procedures

### Secret Naming Convention

| Component     | Secret Name  | Typical Contents              |
| ------------- | ------------ | ----------------------------- |
| API           | `api-env`    | DB, Redis, JWT keys, Firebase |
| Worker        | `worker-env` | Queue URL, API keys           |
| Observability | `obs-env`    | Grafana admin password, etc.  |

### Injecting Secrets into Deployments

**Option A: Environment Variables** (simplest, suitable for most cases)
```yaml
containers:
  - name: api
    env:
      - name: DATABASE_URL
        valueFrom:
          secretKeyRef:
            name: api-env
            key: DATABASE_URL
```

**Option B: Volume Mounts** (for file-based config or bulk injection)
```yaml
spec:
  volumes:
    - name: api-env
      secret:
        secretName: api-env
  containers:
    - name: api
      volumeMounts:
        - name: api-env
          mountPath: /etc/api-secrets
          readOnly: true
```

---

## 3. NetworkPolicies

### Philosophy

**Default Deny Ingress**: All pods start with no ingress permission. Traffic is allowed only when explicitly permitted by policy.

### Policies Implemented

#### `default-deny-ingress` (apps namespace)
- **Scope**: All pods in `apps` namespace
- **Effect**: No external traffic enters by default
- **Rationale**: Prevents accidental exposure; all allowed routes defined explicitly

#### `allow-ingress-to-api` (apps namespace)
- **Scope**: API pods (`app.kubernetes.io/name: api`)
- **From**: Ingress controller pods (ingress namespace)
- **Port**: 8000 (HTTP)
- **Rationale**: External traffic → Ingress → API pods only; no pod-to-pod lateral movement

#### `allow-observability-scrape` (apps namespace)
- **Scope**: All pods in `apps` namespace
- **From**: Observability pods (observability namespace)
- **Port**: 9090 (Prometheus scrape endpoint, configurable per component)
- **Rationale**: Metrics collection without needing direct pod access

### Enabling NetworkPolicies

1. **Cluster Support**: Verify your cluster's CNI plugin supports NetworkPolicies (most do: Calico, Weave, Flannel, etc.; `kind` requires Calico or similar).

2. **Rollout Procedure** (important: test first!):
   - Apply policies in **audit/logging mode** if supported by your network plugin
   - Monitor for blocked connections; adjust policies as needed
   - Enable enforcement gradually (dev → staging → prod)

3. **Testing Locally**:
   ```bash
   # Install Calico for kind (enables NetworkPolicy enforcement)
   kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml

   # Apply policies
   kubectl apply -f k8s/base/network-policies/

   # Verify
   kubectl get networkpolicies -n apps
   ```

### Common Adjustments

**Allow pod-to-pod communication** (e.g., API → Redis cache in same namespace):
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-to-cache
  namespace: apps
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: api
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: redis
      ports:
        - protocol: TCP
          port: 6379
```

**Allow external APIs** (e.g., Firebase, payment provider):
```yaml
egress:
  - to:
      - namespaceSelector: {}  # Any namespace
    ports:
      - protocol: TCP
        port: 443  # HTTPS
```

---

## 4. RBAC (Role-Based Access Control)

### Current State
ServiceAccounts created and ready; RBAC roles deferred pending workload requirements.

### Future: Minimal Required Roles

**API ServiceAccount** → Role → Permissions
```yaml
# Example (not implemented yet):
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: api
  namespace: apps
rules:
  - apiGroups: [""]
    resources: ["secrets", "configmaps"]
    verbs: ["get", "list"]
    # Restrict to specific secrets/configmaps via resourceNames if possible
```

**Trigger for Implementation**: When workloads require Kubernetes API access (e.g., pod auto-restart logic, custom operators).

---

## 5. Resource Quotas & LimitRanges

### Current State
Deferred; example templates provided below for reference.

### Production Overlay (Future)

**LimitRange** (enforce pod-level resource boundaries):
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: apps-limits
  namespace: apps
spec:
  limits:
    - type: Pod
      max:
        cpu: 2
        memory: 2Gi
      min:
        cpu: 100m
        memory: 128Mi
    - type: Container
      default:
        cpu: 500m
        memory: 512Mi
      defaultRequest:
        cpu: 100m
        memory: 128Mi
```

**ResourceQuota** (enforce namespace-level aggregates):
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: apps-quota
  namespace: apps
spec:
  hard:
    requests.cpu: 10
    requests.memory: 20Gi
    limits.cpu: 20
    limits.memory: 40Gi
    pods: 50
```

---

## 6. Pod Security Standards (PSS)

### Current State
Not enforced (standard for development/staging).

### Production: Enable Restricted PSS

```yaml
# k8s/base/namespaces.yaml (update existing namespace)
apiVersion: v1
kind: Namespace
metadata:
  name: apps
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

This enforces:
- Non-root users
- No privileged containers
- Read-only root filesystems
- No host networking/IPC/PID

---

## 7. Secrets Rotation & Audit

### Future Checklist

- [ ] Implement secret rotation policy (e.g., every 90 days)
- [ ] Enable audit logging for Secret access (`kubernetes.io/audit`)
- [ ] Set up alerts for suspicious Secret reads
- [ ] Document incident response (compromised secret workflow)

---

## 8. Compliance & Policy Enforcement (OPA/Gatekeeper)

### Future Consideration

Implement Open Policy Agent (OPA) Gatekeeper for organization-wide policy enforcement:
- Enforce image registry whitelist
- Deny privileged pod specs
- Enforce namespace quotas
- Audit policy violations

---

## Implementation Checklist for Phase 5

- [x] ServiceAccounts created (api, worker, observability)
- [x] Network policies defined (default deny, allow ingress/observability)
- [x] Secret naming convention documented
- [ ] Update API Helm chart to use serviceAccountName
- [ ] Create Makefile target for local secret creation
- [ ] Document secret rotation for staging/prod
- [ ] Integrate Sealed Secrets (future, production-only)
- [ ] Enable RBAC roles (future, on-demand)
- [ ] Enable Pod Security Standards (future, production-only)
- [ ] Implement audit logging (future, production-only)

---

## Next Steps

1. **Immediate**: Update API deployment to reference `api` ServiceAccount (Helm chart).
2. **Short-term**: Add `make secret-local` target for local development.
3. **Medium-term**: Integrate SealedSecrets for staging/prod.
4. **Long-term**: Implement full RBAC, audit logging, and Pod Security Standards for production.

---

Maintain this document as security posture evolves; cross-reference from `04a-k8s-implementation-plan.md`.
