# Grafana Cloud Setup (Optional)

## Overview

Grafana Cloud integration is **required for Druid deployments** but optional for WebApp-only deployments. This guide explains how to configure Grafana Cloud for metrics, logs, traces, and profiling.

## Prerequisites

- Active [Grafana Cloud](https://grafana.com/products/cloud/) account
- Grafana Cloud Stack created (Prometheus, Loki, Tempo, Pyroscope enabled)
- Access to create Grafana Cloud Access Policies

## Configuration Process

### Step 1: Create Access Policy in Grafana Cloud

**Purpose**: Create an access policy that allows AWS EKS to send observability data to Grafana Cloud.

**Instructions**:
1. Navigate to [Grafana Cloud Access Policies](https://grafana.com/orgs/YOUR_ORG/access-policies)
2. Click "Create access policy"
3. Grant permissions:
   - `accesspolicies:read`
   - `accesspolicies:write`
   - `accesspolicies:delete`
4. Create token and save it securely

### Step 2: Gather Grafana Cloud Endpoints

You need the following endpoints from your Grafana Cloud stack:

**1. Prometheus (Metrics)**:
```
https://prometheus-prod-XX-prod-us-west-0.grafana.net
```

**2. Loki (Logs)**:
```
https://logs-prod-XX.grafana.net
```

**3. Tempo (Traces)**:
```
https://tempo-prod-XX-prod-us-west-0.grafana.net:443
```

**4. Pyroscope (Profiling)** (Optional):
```
https://profiles-prod-XX.grafana.net:443
```

**Find endpoints**: Go to [your Grafana Cloud stack dashboard](https://grafana.com/orgs/YOUR_ORG/stacks)

### Step 3: Get Username/Instance IDs

For each service, you need a username (numeric ID):

**Prometheus Username**:
```
Find in: Grafana Cloud → Stack → Prometheus → Details → Username
Format: 123456
```

**Loki Username**:
```
Find in: Grafana Cloud → Stack → Loki → Details → Username
Format: 123456
```

**Tempo Username**:
```
Find in: Grafana Cloud → Stack → Tempo → Details → Username
Format: 123456
```

**Instance ID**:
```
Find in: URL when logged into Grafana Cloud
Format: 123456
```

### Step 4: Configure cdk.context.json

Add Grafana configuration to your Druid infrastructure context:

**File**: `aws-druid-infra/cdk.context.json`

```json
{
  "deployment:eks:grafana:instanceId": "123456",
  "deployment:eks:grafana:key": "glc_eyJ...",
  "deployment:eks:grafana:prometheusHost": "https://prometheus-prod-XX-prod-us-west-0.grafana.net",
  "deployment:eks:grafana:prometheusUsername": "123456",
  "deployment:eks:grafana:lokiHost": "https://logs-prod-XX.grafana.net",
  "deployment:eks:grafana:lokiUsername": "123456",
  "deployment:eks:grafana:tempoHost": "https://tempo-prod-XX-prod-us-west-0.grafana.net/tempo",
  "deployment:eks:grafana:tempoUsername": "123456",
  "deployment:eks:grafana:pyroscopeHost": "https://profiles-prod-XX.grafana.net:443"
}
```

**Configuration fields**:
- `instanceId`: Grafana Cloud instance identifier
- `key`: Access policy token (starts with `glc_`)
- `prometheusHost`: Prometheus endpoint URL
- `prometheusUsername`: Prometheus user ID
- `lokiHost`: Loki endpoint URL
- `lokiUsername`: Loki user ID
- `tempoHost`: Tempo endpoint URL (include `/tempo` path)
- `tempoUsername`: Tempo user ID
- `pyroscopeHost`: Pyroscope endpoint URL (optional)

### Step 5: Deploy Druid Infrastructure

After configuring Grafana credentials:

```bash
cd aws-druid-infra
mvn clean install
cdk deploy
```

The deployment automatically:
1. Creates AWS Secrets Manager secret with Grafana credentials
2. Installs Grafana k8s-monitoring Helm chart on EKS
3. Configures Grafana Alloy agents on all nodes
4. Starts shipping metrics, logs, and traces to Grafana Cloud

## Verification

### Check EKS Pods

```bash
# Verify Grafana monitoring pods are running
kubectl get pods -n monitoring

# Expected output:
# NAME                                READY   STATUS    RESTARTS   AGE
# k8s-monitoring-alloy-0              2/2     Running   0          5m
# k8s-monitoring-alloy-1              2/2     Running   0          5m
# kube-state-metrics-...              1/1     Running   0          5m
```

### Check Grafana Cloud

1. Log into Grafana Cloud dashboard
2. Navigate to **Explore** → **Prometheus**
3. Query: `up{cluster="fff-eks"}`
4. Should see metrics from your EKS cluster

**Logs**:
1. Navigate to **Explore** → **Loki**
2. Query: `{cluster="fff-eks"}`
3. Should see logs from pods

**Traces**:
1. Navigate to **Explore** → **Tempo**
2. Search for recent traces
3. Should see distributed traces from Druid

## Troubleshooting

### No metrics in Grafana Cloud

**Check Alloy pods**:
```bash
kubectl logs -n monitoring k8s-monitoring-alloy-0 -c alloy
```

**Common issues**:
- Invalid Grafana token (check `hosted:eks:grafana:key`)
- Incorrect endpoint URLs
- Network connectivity (check VPC/security groups)

### Authentication errors

**Check AWS Secrets Manager**:
```bash
aws secretsmanager list-secrets \
  --query 'SecretList[?contains(Name, `grafana`)]'
```

**Verify secret contains correct credentials**

### Pods not shipping data

**Check service account**:
```bash
kubectl get serviceaccount -n monitoring
kubectl describe serviceaccount k8s-monitoring-alloy -n monitoring
```

**Verify IRSA annotation** is present

## Alternative: Manual Setup

If automatic deployment fails, you can manually configure Grafana credentials using the bootstrap repository script:

```bash
cd bootstrap/scripts/grafana

# Create inputs.json
cat <<EOF > inputs.json
{
  "cloud_access_policy_token": "glc_eyJ...",
  "prometheus_host": "https://prometheus-prod-XX-prod-us-west-0.grafana.net",
  "prometheus_username": "123456",
  "loki_host": "https://logs-prod-XX.grafana.net",
  "loki_username": "123456",
  "tempo_host": "https://tempo-prod-XX-prod-us-west-0.grafana.net:443",
  "tempo_username": "123456",
  "alias": "druid-monitoring",
  "instance_id": "123456",
  "region": "prod-us-west-0"
}
EOF

# Run setup script
./create.sh inputs.json
```

**What this does**:
1. Creates Grafana Cloud access policy
2. Creates AWS Secrets Manager secret in correct format
3. Outputs secret ARN for EKS to use

## Cost Estimate

**Grafana Cloud Free Tier**:
- 10,000 series for Prometheus
- 50 GB logs for Loki
- 50 GB traces for Tempo

**Paid tiers** (if exceeding free tier):
- Prometheus: $8/month per 10k series
- Loki: $0.50/GB
- Tempo: $0.50/GB

**Typical Druid cluster**: Stays within free tier for development/testing

## Related Documentation

- [Druid Overview →](/druid/overview.md)
- [EKS Configuration →](/druid/eks.md)
- [Druid Grafana Integration →](/druid/grafana.md)
- [Grafana Cloud Documentation](https://grafana.com/docs/grafana-cloud/)
