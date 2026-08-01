# Spring Boot Metrics Integration Guide

This guide explains how to integrate your Spring Boot microservices with the Prometheus monitoring stack.

## Overview

The monitoring stack collects metrics from your Spring Boot applications using Prometheus. This requires:
1. Adding Micrometer Prometheus dependency
2. Configuring Actuator endpoints
3. Adding Kubernetes pod annotations

## Step 1: Add Maven Dependencies

Add the Micrometer Prometheus registry to each microservice's `pom.xml`:

```xml
<!-- Prometheus Metrics -->
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>

<!-- Ensure Actuator is included (already present in your services) -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
```

## Step 2: Configure Application Properties

Update `application.yml` for each microservice to expose Prometheus metrics:

```yaml
# =============================================================================
# ACTUATOR & METRICS CONFIGURATION
# =============================================================================
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus,metrics
      base-path: /actuator
  endpoint:
    health:
      show-details: always
    prometheus:
      enabled: true
  metrics:
    export:
      prometheus:
        enabled: true
    tags:
      application: ${spring.application.name}
    distribution:
      percentiles-histogram:
        http.server.requests: true
      slo:
        http.server.requests: 50ms, 100ms, 200ms, 500ms, 1s, 2s, 5s
```

## Step 3: Add Custom Metrics (Optional)

Create custom metrics in your services:

```java
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import org.springframework.stereotype.Component;

@Component
public class OrderMetrics {
    
    private final Counter ordersCreated;
    private final Counter ordersFailed;
    private final Timer orderProcessingTimer;
    
    public OrderMetrics(MeterRegistry registry) {
        this.ordersCreated = Counter.builder("orders.created.total")
            .description("Total number of orders created")
            .tag("service", "order-service")
            .register(registry);
            
        this.ordersFailed = Counter.builder("orders.failed.total")
            .description("Total number of failed orders")
            .tag("service", "order-service")
            .register(registry);
            
        this.orderProcessingTimer = Timer.builder("orders.processing.time")
            .description("Order processing time")
            .tag("service", "order-service")
            .register(registry);
    }
    
    public void recordOrderCreated() {
        ordersCreated.increment();
    }
    
    public void recordOrderFailed() {
        ordersFailed.increment();
    }
    
    public Timer.Sample startTimer() {
        return Timer.start();
    }
    
    public void stopTimer(Timer.Sample sample) {
        sample.stop(orderProcessingTimer);
    }
}
```

## Step 4: Update Helm Chart Deployments

Add Prometheus annotations to your service deployments. Update each service's Helm template:

```yaml
# Example: helm-charts/api-gateway/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Values.gateway.label }}-depl
spec:
  template:
    metadata:
      labels:
        app: {{ .Values.gateway.label }}
      annotations:
        # Prometheus scraping annotations
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/actuator/prometheus"
```

### Services to Update

Add the annotations to all microservices:

| Service | Port | Path |
|---------|------|------|
| api-gateway | 8080 | /actuator/prometheus |
| auth-service | 8080 | /actuator/prometheus |
| user-service | 8080 | /actuator/prometheus |
| product-service | 8080 | /actuator/prometheus |
| category-service | 8080 | /actuator/prometheus |
| cart-service | 8080 | /actuator/prometheus |
| order-service | 8080 | /actuator/prometheus |
| notification-service | 8080 | /actuator/prometheus |
| service-registry | 8761 | /actuator/prometheus |

## Step 5: Verify Metrics Endpoint

After deployment, verify metrics are exposed:

```bash
# Port forward to a service
kubectl port-forward svc/api-gateway 8080:80 -n purely

# Check metrics endpoint
curl http://localhost:8080/actuator/prometheus
```

You should see output like:
```
# HELP jvm_memory_used_bytes The amount of used memory
# TYPE jvm_memory_used_bytes gauge
jvm_memory_used_bytes{area="heap",id="G1 Eden Space",} 2.5165824E7
...
# HELP http_server_requests_seconds  
# TYPE http_server_requests_seconds histogram
http_server_requests_seconds_bucket{exception="None",method="GET",outcome="SUCCESS",status="200",uri="/api/products",le="0.05",} 100.0
...
```

## Available Metrics

### JVM Metrics
- `jvm_memory_used_bytes` - Memory usage
- `jvm_gc_pause_seconds` - GC pause time
- `jvm_threads_live_threads` - Active threads
- `jvm_classes_loaded_classes` - Loaded classes

### HTTP Metrics
- `http_server_requests_seconds` - HTTP request latency
- `http_server_requests_seconds_count` - Request count
- `http_server_requests_seconds_sum` - Total request time

### Application Metrics
- `process_cpu_usage` - CPU usage
- `process_uptime_seconds` - Application uptime
- `system_load_average_1m` - System load

## Grafana Dashboard Queries

### Request Rate by Service
```promql
sum(rate(http_server_requests_seconds_count{application!=""}[5m])) by (application)
```

### Error Rate
```promql
sum(rate(http_server_requests_seconds_count{status=~"5.."}[5m])) by (application)
/ 
sum(rate(http_server_requests_seconds_count[5m])) by (application)
```

### 95th Percentile Latency
```promql
histogram_quantile(0.95, sum(rate(http_server_requests_seconds_bucket[5m])) by (le, application))
```

### JVM Memory Usage
```promql
sum(jvm_memory_used_bytes{area="heap"}) by (application)
```

### Active Threads
```promql
jvm_threads_live_threads
```

## Example: Updated api-gateway pom.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <!-- ... existing content ... -->
    
    <dependencies>
        <!-- Existing dependencies -->
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-gateway</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-netflix-eureka-client</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>
        
        <!-- ADD: Prometheus Metrics -->
        <dependency>
            <groupId>io.micrometer</groupId>
            <artifactId>micrometer-registry-prometheus</artifactId>
        </dependency>
        
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>
</project>
```

## Example: Updated application.yml

```yaml
server:
  port: 8080
  
spring:
  application:
    name: api-gateway
  # ... existing config ...

# ADD: Full Actuator Configuration
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus,metrics
      base-path: /actuator
  endpoint:
    health:
      show-details: always
    prometheus:
      enabled: true
  metrics:
    export:
      prometheus:
        enabled: true
    tags:
      application: ${spring.application.name}
      environment: ${ENVIRONMENT:dev}
    distribution:
      percentiles-histogram:
        http.server.requests: true
```

## Troubleshooting

### Prometheus not scraping service

1. Check pod annotations:
```bash
kubectl describe pod <pod-name> -n purely | grep -A 5 Annotations
```

2. Verify metrics endpoint is accessible:
```bash
kubectl exec -it <pod-name> -n purely -- curl localhost:8080/actuator/prometheus
```

3. Check Prometheus targets:
```bash
kubectl port-forward svc/prometheus 9090:9090 -n monitoring
# Open http://localhost:9090/targets
```

### Metrics not appearing in Grafana

1. Verify Prometheus datasource is configured
2. Check if metrics are in Prometheus:
   - Go to Prometheus UI → Graph
   - Query: `http_server_requests_seconds_count{application="api-gateway"}`
3. Check time range in Grafana

### Common Issues

| Issue | Solution |
|-------|----------|
| `/actuator/prometheus` returns 404 | Add micrometer-registry-prometheus dependency |
| Prometheus not discovering pods | Check pod annotations and RBAC |
| Empty metrics | Verify management.endpoints.web.exposure.include |
| High cardinality warnings | Limit label values in custom metrics |
