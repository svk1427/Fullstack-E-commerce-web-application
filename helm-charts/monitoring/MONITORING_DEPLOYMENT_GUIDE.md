# Monitoring Stack Deployment Guide

Complete guide for deploying the monitoring stack (Fluent Bit, Prometheus, Grafana, Loki) for Purely E-Commerce.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           MONITORING ARCHITECTURE                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │   Node 1    │  │   Node 2    │  │   Node 3    │  │   Node N    │            │
│  │             │  │             │  │             │  │             │            │
│  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │            │
│  │ │Fluent   │ │  │ │Fluent   │ │  │ │Fluent   │ │  │ │Fluent   │ │ DaemonSet  │
│  │ │Bit      │ │  │ │Bit      │ │  │ │Bit      │ │  │ │Bit      │ │            │
│  │ └────┬────┘ │  │ └────┬────┘ │  │ └────┬────┘ │  │ └────┬────┘ │            │
│  │ ┌────┴────┐ │  │ ┌────┴────┐ │  │ ┌────┴────┐ │  │ ┌────┴────┐ │            │
│  │ │Node     │ │  │ │Node     │ │  │ │Node     │ │  │ │Node     │ │ DaemonSet  │
│  │ │Exporter │ │  │ │Exporter │ │  │ │Exporter │ │  │ │Exporter │ │            │
│  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │            │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘            │
│         │                │                │                │                    │
│         └────────────────┼────────────────┼────────────────┘                    │
│                          │                │                                      │
│                          ▼                ▼                                      │
│  ┌───────────────────────────────────────────────────────────────────┐          │
│  │                         MONITORING NAMESPACE                       │          │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────────┐│          │
│  │  │    LOKI     │  │  PROMETHEUS │  │    KUBE-STATE-METRICS       ││          │
│  │  │  (Logs)     │  │  (Metrics)  │  │    (K8s Object Metrics)     ││          │
│  │  │             │  │             │  │                             ││          │
│  │  └──────┬──────┘  └──────┬──────┘  └─────────────────────────────┘│          │
│  │         │                │                                         │          │
│  │         └────────┬───────┘                                         │          │
│  │                  │                                                 │          │
│  │                  ▼                                                 │          │
│  │  ┌───────────────────────────────────────────────────────────────┐│          │
│  │  │                        GRAFANA                                 ││          │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       ││          │
│  │  │  │Cluster   │  │Pod       │  │Logs      │  │Custom    │       ││          │
│  │  │  │Dashboard │  │Metrics   │  │Explorer  │  │Dashboards│       ││          │
│  │  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘       ││          │
│  │  └───────────────────────────────────────────────────────────────┘│          │
│  └───────────────────────────────────────────────────────────────────┘          │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Components

| Component | Type | Purpose |
|-----------|------|---------|
| **Fluent Bit** | DaemonSet | Collects logs from all containers on every node |
| **Node Exporter** | DaemonSet | Collects node-level hardware and OS metrics |
| **Loki** | StatefulSet | Log aggregation and storage |
| **Prometheus** | StatefulSet | Metrics collection and storage |
| **Kube State Metrics** | Deployment | Exposes Kubernetes object metrics |
| **Grafana** | Deployment | Visualization and dashboards |
| **Alertmanager** | Deployment (Optional) | Alert routing and notification |

## Prerequisites

1. **Kubernetes Cluster** (EKS recommended)
2. **Helm 3.x** installed
3. **kubectl** configured with cluster access
4. **Storage Class** (gp2 for AWS EKS)

## Quick Start

### 1. Deploy Monitoring Stack (Development)

```bash
# Navigate to helm-charts directory
cd helm-charts

# Deploy with development values
helm upgrade --install monitoring ./monitoring \
  --namespace monitoring \
  --create-namespace \
  -f environments/dev/monitoring.yaml

# Verify deployment
kubectl get all -n monitoring
```

### 2. Deploy Monitoring Stack (Production)

```bash
# Deploy with production values
helm upgrade --install monitoring ./monitoring \
  --namespace monitoring \
  --create-namespace \
  -f environments/prod/monitoring.yaml \
  --set grafana.admin.password="<YOUR_SECURE_PASSWORD>"

# Verify deployment
kubectl get all -n monitoring
```

## Accessing Services

### Option 1: Port Forwarding (Development)

```bash
# Access Grafana
kubectl port-forward svc/grafana 3000:3000 -n monitoring
# Open: http://localhost:3000

# Access Prometheus
kubectl port-forward svc/prometheus 9090:9090 -n monitoring
# Open: http://localhost:9090

# Access Loki (for testing)
kubectl port-forward svc/loki 3100:3100 -n monitoring
```

### Option 2: Ingress (Production)

When ingress is enabled, access via:
- Grafana: `https://grafana.purely.internal`
- Prometheus: `https://prometheus.purely.internal`

## Grafana Login

**Default Credentials:**
- Username: `admin`
- Password: `admin` (or the password set via `--set grafana.admin.password=<password>`)

## Pre-configured Dashboards

The stack includes three pre-configured dashboards:

### 1. Kubernetes Cluster Overview
- Total nodes, pods, pending/failed pods
- Node CPU and memory usage
- Memory usage by namespace

### 2. Pod Metrics
- Pod CPU usage
- Pod memory usage
- Pod network I/O
- Pod restart count
- Namespace selector

### 3. Logs Explorer
- Application logs viewer
- Log volume by namespace
- Search functionality
- Namespace filter

## Adding Prometheus Metrics to Your Services

To enable Prometheus scraping for your microservices, add these annotations to your pods:

```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/actuator/prometheus"
```

### For Spring Boot Applications

Add the Micrometer Prometheus dependency:

```xml
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
```

Add to `application.yml`:

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus
  endpoint:
    prometheus:
      enabled: true
  metrics:
    export:
      prometheus:
        enabled: true
```

## Viewing Logs in Grafana

1. Open Grafana
2. Go to **Explore** (compass icon)
3. Select **Loki** as the data source
4. Use LogQL to query logs:

```logql
# All logs from a specific namespace
{namespace="purely"}

# Filter by pod name
{namespace="purely", pod=~"api-gateway.*"}

# Search for errors
{namespace="purely"} |= "ERROR"

# Filter by container
{namespace="purely", container="api-gateway"}
```

## Useful PromQL Queries

### Node Metrics

```promql
# CPU usage per node
100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage per node
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk usage
100 - ((node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100)
```

### Pod/Container Metrics

```promql
# CPU usage by pod
sum(rate(container_cpu_usage_seconds_total{container!=""}[5m])) by (namespace, pod)

# Memory usage by pod
sum(container_memory_working_set_bytes{container!=""}) by (namespace, pod)

# Pod restart count
sum(kube_pod_container_status_restarts_total) by (namespace, pod)

# Pods not ready
kube_pod_status_ready{condition="false"}
```

### Application Metrics

```promql
# HTTP request rate
sum(rate(http_server_requests_seconds_count[5m])) by (service)

# HTTP error rate (5xx)
sum(rate(http_server_requests_seconds_count{status=~"5.."}[5m])) by (service)

# HTTP latency (95th percentile)
histogram_quantile(0.95, sum(rate(http_server_requests_seconds_bucket[5m])) by (le, service))
```

## Configuring Alerts

### Enable Alertmanager

Update your values file:

```yaml
alertmanager:
  enabled: true
  notifications:
    slack:
      enabled: true
      webhookUrl: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
      channel: "#alerts"
```

### Pre-configured Alerts

The stack includes alerts for:
- Pod crash looping
- Pods not ready
- Deployment replica mismatch
- High node CPU/memory usage
- Low disk space
- Node not ready
- High HTTP error rate
- High HTTP latency

## Scaling Considerations

### For High-Volume Environments

1. **Increase Loki storage:**
```yaml
loki:
  storage:
    size: 100Gi
```

2. **Increase Prometheus retention:**
```yaml
prometheus:
  storage:
    size: 200Gi
    retentionDays: 60
```

3. **Add more resources:**
```yaml
prometheus:
  resources:
    requests:
      cpu: 1000m
      memory: 4Gi
    limits:
      cpu: 4000m
      memory: 8Gi
```

## Troubleshooting

### Check Component Status

```bash
# View all monitoring resources
kubectl get all -n monitoring

# Check pod logs
kubectl logs -n monitoring -l app=fluent-bit --tail=100
kubectl logs -n monitoring -l app=prometheus --tail=100
kubectl logs -n monitoring -l app=grafana --tail=100
kubectl logs -n monitoring -l app=loki --tail=100

# Check DaemonSet status (Fluent Bit and Node Exporter)
kubectl get daemonset -n monitoring

# Verify Fluent Bit is running on all nodes
kubectl get pods -n monitoring -l app=fluent-bit -o wide
```

### Common Issues

1. **Fluent Bit not collecting logs:**
   - Check if container runtime is Docker or containerd
   - Verify log path in ConfigMap

2. **Prometheus not scraping targets:**
   - Check service annotations
   - Verify RBAC permissions

3. **Grafana datasource connection failed:**
   - Check service names in datasource config
   - Verify services are running

4. **PVC pending:**
   - Ensure storage class exists
   - Check node capacity

## Cleanup

```bash
# Remove monitoring stack
helm uninstall monitoring -n monitoring

# Delete namespace (removes PVCs too)
kubectl delete namespace monitoring

# Or keep PVCs for data persistence
kubectl delete namespace monitoring --cascade=orphan
```

## File Structure

```
helm-charts/monitoring/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── namespace.yaml
    ├── fluent-bit-daemonset.yaml
    ├── fluent-bit-configmap.yaml
    ├── fluent-bit-rbac.yaml
    ├── loki.yaml
    ├── loki-configmap.yaml
    ├── prometheus.yaml
    ├── prometheus-configmap.yaml
    ├── prometheus-rules.yaml
    ├── prometheus-rbac.yaml
    ├── kube-state-metrics.yaml
    ├── kube-state-metrics-rbac.yaml
    ├── node-exporter.yaml
    ├── node-exporter-rbac.yaml
    ├── grafana.yaml
    ├── grafana-secrets.yaml
    ├── grafana-datasources.yaml
    ├── grafana-dashboards-config.yaml
    ├── grafana-dashboards.yaml
    ├── alertmanager.yaml
    └── ingress.yaml
```

## Next Steps

1. **Create custom dashboards** for your specific microservices
2. **Configure alerting** to Slack, PagerDuty, or email
3. **Add application-specific metrics** using Micrometer
4. **Set up log-based alerting** using Loki rules
5. **Integrate with your CI/CD pipeline** for deployment monitoring
