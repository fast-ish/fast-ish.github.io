# Grafana Cloud Observability

## Overview

Grafana Cloud provides comprehensive observability for the EKS cluster and Apache Druid deployment. The integration collects metrics (Prometheus), logs (Loki), traces (Tempo), and profiles (Pyroscope) from all components.

## Grafana k8s-monitoring Chart

### Chart Configuration

**Repository**: `https://grafana.github.io/helm-charts`

**Chart Name**: `k8s-monitoring`

**Version**: `v3.3.2`

**Release Name**: `k8s-monitoring`

**Namespace**: `monitoring`

### How Configuration is Used

**Input (cdk.context.json)**:
```json
{
  "hosted:id": "fff",
  "hosted:eks:grafana:instanceId": "000000",
  "hosted:eks:grafana:key": "glc_xyz...",
  "hosted:eks:grafana:prometheusHost": "https://prometheus-prod-000-prod-us-west-0.grafana.net",
  "hosted:eks:grafana:prometheusUsername": "0000000",
  "hosted:eks:grafana:lokiHost": "https://logs-prod-000.grafana.net",
  "hosted:eks:grafana:lokiUsername": "000000",
  "hosted:eks:grafana:tempoHost": "https://tempo-prod-000-prod-us-west-0.grafana.net/tempo",
  "hosted:eks:grafana:tempoUsername": "000000",
  "hosted:eks:grafana:pyroscopeHost": "https://profiles-prod-000.grafana.net:443"
}
```

**Template (helm/grafana.mustache)**:
```yaml
cluster:
  name: "{{hosted:id}}-eks"  # fff-eks

destinations:
  - name: grafana-cloud-metrics
    type: prometheus
    url: {{hosted:eks:grafana:prometheusHost}}/api/prom/push
    auth:
      type: basic
      username: "{{hosted:eks:grafana:prometheusUsername}}"
      password: {{hosted:eks:grafana:key}}
```

**Generates Helm Values**:
```yaml
cluster:
  name: fff-eks

destinations:
  - name: grafana-cloud-metrics
    type: prometheus
    url: https://prometheus-prod-000-prod-us-west-0.grafana.net/api/prom/push
    auth:
      type: basic
      username: "0000000"
      password: "glc_xyz..."
```

## Grafana Cloud Setup

### 1. Create Grafana Cloud Account

**Sign up**: https://grafana.com/products/cloud/

**Create a Stack**:
- Navigate to your Grafana Cloud portal
- Click "Create Stack"
- Choose region (select closest to your AWS region)
- Name your stack (e.g., "production-monitoring")

### 2. Generate API Key

**Create API Key**:
1. Go to **"Cloud Portal"** → **"API Keys"**
2. Click **"Add API Key"**
3. Name: `eks-monitoring`
4. Role: **"Admin"** or create custom role

**Required Permissions**:
- **Metrics**: Read and Write (Prometheus)
- **Logs**: Read and Write (Loki)
- **Traces**: Read and Write (Tempo)
- **Profiles**: Read and Write (Pyroscope)
- **Alerts**: Read and Write
- **Rules**: Read and Write

**API Key Format**:
```
glc_xyz123abc456def789...
```

### 3. Get Endpoint URLs

Navigate to each service in Grafana Cloud:

**Prometheus (Metrics)**:
- Go to **"Metrics"** → **"Data Sources"** → **"Prometheus"**
- Copy **"Remote Write Endpoint"**
- Example: `https://prometheus-prod-000-prod-us-west-0.grafana.net/api/prom/push`
- Copy **"Username"** (numeric ID)

**Loki (Logs)**:
- Go to **"Logs"** → **"Data Sources"** → **"Loki"**
- Copy **"URL"**
- Example: `https://logs-prod-000.grafana.net`
- Copy **"Username"** (numeric ID)

**Tempo (Traces)**:
- Go to **"Traces"** → **"Data Sources"** → **"Tempo"**
- Copy **"Remote Write Endpoint"**
- Example: `https://tempo-prod-000-prod-us-west-0.grafana.net/tempo`
- Copy **"Username"** (numeric ID)

**Pyroscope (Profiles)**:
- Go to **"Profiles"** → **"Connect a data source"**
- Copy **"URL"**
- Example: `https://profiles-prod-000.grafana.net:443`

### 4. Configure in cdk.context.json

```json
{
  "hosted:eks:grafana:instanceId": "000000",
  "hosted:eks:grafana:key": "glc_xyz123abc456def789...",
  "hosted:eks:grafana:prometheusHost": "https://prometheus-prod-000-prod-us-west-0.grafana.net",
  "hosted:eks:grafana:prometheusUsername": "0000000",
  "hosted:eks:grafana:lokiHost": "https://logs-prod-000.grafana.net",
  "hosted:eks:grafana:lokiUsername": "000000",
  "hosted:eks:grafana:tempoHost": "https://tempo-prod-000-prod-us-west-0.grafana.net/tempo",
  "hosted:eks:grafana:tempoUsername": "000000",
  "hosted:eks:grafana:pyroscopeHost": "https://profiles-prod-000.grafana.net:443"
}
```

## Observability Components

### Metrics (Prometheus)

**Enabled Features**:
```yaml
clusterMetrics:
  enabled: true
  opencost:
    enabled: true           # Cost monitoring
  kepler:
    enabled: true           # Energy monitoring
```

**Metrics Collected**:
- **Node Metrics**:
  - CPU usage
  - Memory usage
  - Disk I/O
  - Network I/O
  - Filesystem usage

- **Pod Metrics**:
  - Container CPU/memory
  - Restart counts
  - Resource requests/limits
  - OOM kills

- **Druid Metrics** (via Prometheus emitter):
  - Query latencies (P50, P95, P99)
  - Segment counts
  - JVM heap usage
  - GC pauses
  - Ingestion lag
  - Task success rates

- **MSK Metrics**:
  - Broker CPU/disk
  - Messages per second
  - Bytes in/out
  - Consumer lag

- **Cost Metrics** (OpenCost):
  - Per-pod costs
  - Per-namespace costs
  - Resource efficiency

**Prometheus Endpoint**: `https://prometheus-prod-000-prod-us-west-0.grafana.net/api/prom/push`

### Logs (Loki)

**Enabled Features**:
```yaml
nodeLogs:
  enabled: true
podLogs:
  enabled: true
clusterEvents:
  enabled: true
```

**Logs Collected**:
- **Node Logs**:
  - Kubelet logs
  - Container runtime logs
  - System logs

- **Pod Logs**:
  - All container stdout/stderr
  - Application logs
  - Druid component logs
  - MSK client logs

- **Cluster Events**:
  - Pod scheduling events
  - Node events
  - Deployment events
  - ConfigMap/Secret changes

**Loki Endpoint**: `https://logs-prod-000.grafana.net/loki/api/v1/push`

**Log Labels**:
```yaml
labels:
  cluster: "fff-eks"
  namespace: "druid"
  pod: "druid-broker-0"
  container: "druid"
```

### Traces (Tempo)

**Enabled Features**:
```yaml
applicationObservability:
  enabled: true
  receivers:
    otlp:
      grpc:
        enabled: true
        port: 4317
      http:
        enabled: true
        port: 4318
    zipkin:
      enabled: true
      port: 9411
```

**Traces Collected**:
- **Druid Query Traces**:
  - Query execution spans
  - Broker → Historical communication
  - Segment loading
  - Result merging

- **Application Traces** (if instrumented):
  - HTTP requests
  - Database queries
  - Kafka produce/consume
  - Service dependencies

**Tempo Endpoint**: `https://tempo-prod-000-prod-us-west-0.grafana.net/tempo`

**Trace Format**: OpenTelemetry Protocol (OTLP)

### Profiles (Pyroscope)

**Enabled Features**:
```yaml
profiling:
  enabled: true
autoInstrumentation:
  enabled: true
```

**Profiles Collected**:
- **CPU Profiles**:
  - Flamegraphs
  - Function call trees
  - Hot paths

- **Memory Profiles**:
  - Allocation sites
  - Heap usage
  - Memory leaks

**Pyroscope Endpoint**: `https://profiles-prod-000.grafana.net:443`

**Supported Languages**:
- Java (Druid)
- Go
- Python
- Node.js
- .NET

## Grafana Alloy

### Alloy Operator

**Purpose**: Manages Grafana Alloy instances

**Chart**: `grafana/alloy-operator v0.3.8`

**Namespace**: `alloy-system`

**What it does**:
- Provides CRDs for Alloy configuration
- Manages Alloy agent lifecycle
- Required by k8s-monitoring chart v3+

### Alloy Agents

**DaemonSet**: Runs on every node

**Responsibilities**:
- Scrape Prometheus metrics from pods
- Collect logs from containers
- Forward traces from applications
- Ship profiles to Pyroscope

**Configuration**:
```yaml
alloy-metrics:
  enabled: true
  alloy:
    extraEnv:
      - name: GCLOUD_RW_API_KEY
        value: {{hosted:eks:grafana:key}}
      - name: CLUSTER_NAME
        value: {{hosted:id}}-eks
```

## Annotation-Based Discovery

**Enabled Feature**:
```yaml
annotationAutodiscovery:
  enabled: true
```

**How it works**:

**Add annotations to pods**:
```yaml
apiVersion: v1
kind: Pod
metadata:
  annotations:
    k8s.grafana.com/scrape: "true"
    k8s.grafana.com/metrics.portNumber: "9000"
    k8s.grafana.com/metrics.path: "/metrics"
```

**Alloy automatically**:
- Discovers annotated pods
- Scrapes metrics from specified port
- Sends to Grafana Cloud Prometheus

**Druid uses this**:
```yaml
annotations:
  "k8s.grafana.com/scrape": "true"
  "k8s.grafana.com/metrics.portNumber": "9000"
```

## Prometheus Operator Support

**Enabled Feature**:
```yaml
prometheusOperatorObjects:
  enabled: true
```

**Supports**:
- ServiceMonitor CRDs
- PodMonitor CRDs
- PrometheusRule CRDs

**Example ServiceMonitor**:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: druid-broker
  namespace: druid
spec:
  selector:
    matchLabels:
      app: druid
      component: broker
  endpoints:
    - port: metrics
      interval: 30s
```

## Dashboards

### Pre-built Dashboards

**Kubernetes Monitoring**:
- Cluster overview
- Node details
- Pod details
- Namespace overview
- Workload analysis

**Cost Monitoring** (OpenCost):
- Cluster costs
- Namespace costs
- Pod costs
- Resource efficiency

**Energy Monitoring** (Kepler):
- Power consumption
- Carbon footprint
- Energy efficiency

### Custom Druid Dashboards

**Create dashboard for Druid**:

**Metrics to visualize**:
- Query latency histogram
- Segment count by datasource
- JVM heap usage
- Ingestion lag
- Task success/failure rates

**Example PromQL queries**:

**Query Latency P95**:
```promql
histogram_quantile(0.95,
  sum(rate(druid_query_time_bucket{cluster="fff-eks"}[5m])) by (le, datasource)
)
```

**Segment Count**:
```promql
sum(druid_segment_count{cluster="fff-eks"}) by (datasource)
```

**JVM Heap Usage**:
```promql
druid_jvm_mem_used{cluster="fff-eks", area="heap"} /
druid_jvm_mem_max{cluster="fff-eks", area="heap"} * 100
```

## Alerting

### Create Alert Rules

**In Grafana Cloud**:
1. Navigate to **"Alerting"** → **"Alert rules"**
2. Click **"New alert rule"**
3. Choose data source: Prometheus
4. Define query
5. Set evaluation conditions
6. Configure notifications

**Example Alert: High Query Latency**:
```yaml
alert: DruidHighQueryLatency
expr: |
  histogram_quantile(0.95,
    sum(rate(druid_query_time_bucket{cluster="fff-eks"}[5m])) by (le)
  ) > 5000
for: 5m
labels:
  severity: warning
annotations:
  summary: "Druid query latency is high"
  description: "P95 query latency is {{ $value }}ms for cluster fff-eks"
```

**Example Alert: Ingestion Lag**:
```yaml
alert: DruidIngestionLag
expr: |
  druid_ingest_events_lag{cluster="fff-eks"} > 10000
for: 10m
labels:
  severity: critical
annotations:
  summary: "Druid ingestion is lagging"
  description: "Ingestion lag is {{ $value }} messages for cluster fff-eks"
```

### Notification Channels

**Configure in Grafana Cloud**:
- Email
- Slack
- PagerDuty
- Webhook
- Microsoft Teams

## Viewing Observability Data

### Access Grafana Cloud

**URL**: `https://your-stack.grafana.net`

**Login**: Use your Grafana Cloud credentials

### Explore Metrics

1. Go to **"Explore"**
2. Select **"Prometheus"** data source
3. Choose metric: `druid_query_time_bucket`
4. Filter by cluster: `{cluster="fff-eks"}`
5. Run query

### View Logs

1. Go to **"Explore"**
2. Select **"Loki"** data source
3. Query: `{cluster="fff-eks", namespace="druid"}`
4. Filter by pod, container, etc.

### Analyze Traces

1. Go to **"Explore"**
2. Select **"Tempo"** data source
3. Search by:
   - Service name
   - Duration
   - Tags

### View Profiles

1. Go to **"Explore"**
2. Select **"Pyroscope"** data source
3. Choose application
4. View flamegraph

## Troubleshooting

### No Metrics Appearing

**Check Alloy pods**:
```bash
kubectl get pods -n monitoring
kubectl logs -n monitoring <alloy-pod>
```

**Verify API key**:
```bash
kubectl get secret -n monitoring grafana-cloud-metrics-k8s-monitoring -o yaml
```

**Test connectivity**:
```bash
kubectl run -n monitoring test-grafana --image=curlimages/curl --rm -it --restart=Never -- \
  curl -u 0000000:glc_xyz... https://prometheus-prod-000.grafana.net/api/prom/push
```

### High Cardinality Issues

**Symptoms**:
- Slow query performance in Grafana
- "Too many series" errors

**Solutions**:
1. Reduce label cardinality
2. Use relabeling to drop high-cardinality labels
3. Aggregate metrics before sending

### Missing Logs

**Check pod logs collection**:
```bash
kubectl logs -n monitoring <alloy-pod> | grep loki
```

**Verify Loki endpoint**:
```bash
kubectl run -n monitoring test-loki --image=curlimages/curl --rm -it --restart=Never -- \
  curl -u 000000:glc_xyz... https://logs-prod-000.grafana.net/loki/api/v1/push
```

## Next Steps

- [Apache Druid Deployment →](druid.md)
- [MSK Integration →](msk.md)
- [EKS Cluster →](eks.md)
- [VPC Configuration →](vpc.md)
