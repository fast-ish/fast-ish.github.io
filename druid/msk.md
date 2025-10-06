# Amazon MSK (Kafka)

## Overview

Amazon MSK (Managed Streaming for Apache Kafka) provides real-time data ingestion for Apache Druid. The MSK cluster enables streaming data pipelines with automatic broker management, encryption, and high availability across multiple Availability Zones.

## MSK Cluster Configuration

### Cluster Settings

**Cluster Type**: MSK Serverless

**Cluster Name**: `{id}-{release}-druid-msk`

**Example**: `fff-streaming-druid-msk`

**Authentication**: IAM (SASL/IAM)

**Network**: Deployed in VPC private subnets

**Scaling**: Automatic (serverless)

### How Configuration is Used

**Input (cdk.context.json)**:
```json
{
  "hosted:id": "fff",
  "hosted:eks:druid:release": "streaming",
  "hosted:account": "000000000000",
  "hosted:region": "us-west-2"
}
```

**Template (druid/setup/ingestion.mustache)**:
```yaml
kafka:
  name: {{hosted:id}}-{{hosted:eks:druid:release}}-druid-msk  # fff-streaming-druid-msk
  clients:
    - name: {{hosted:id}}-{{hosted:eks:druid:release}}-druid-msk-client
      serviceAccount:
        metadata:
          name: {{hosted:id}}-{{hosted:eks:druid:release}}-druid-msk-sa
          namespace: api
  tags:
    "{{hosted:domain}}:resource-type": msk
    "{{hosted:domain}}:component": {{hosted:id}}-{{hosted:eks:druid:release}}-druid-msk
```

**CDK Construct Used**: [`MskConstruct`](https://github.com/fast-ish/cdk-common/blob/main/src/main/java/fasti/sh/execute/aws/msk/MskConstruct.java)

**What gets created**:
```java
// MSK Serverless Cluster
CfnServerlessCluster.Builder.create(this, clusterName)
  .clusterName("fff-streaming-druid-msk")
  .vpcConfigs(List.of(
    VpcConfigProperty.builder()
      .subnetIds(vpc.getPrivateSubnets())  // All private subnets
      .securityGroups(securityGroupIds)
      .build()
  ))
  .clientAuthentication(
    ClientAuthenticationProperty.builder()
      .sasl(SaslProperty.builder()
        .iam(IamProperty.builder()
          .enabled(true)  // IAM authentication required
          .build())
        .build())
      .build()
  )
  .build();
```

**Why MSK Serverless?**
- **No capacity planning**: Scales automatically based on throughput
- **Pay-per-use**: Only pay for actual data transferred and stored
- **Simplified operations**: No broker management or patching
- **IAM integration**: Native AWS IAM authentication

## IAM Service Account for MSK Access

### Service Account

**Name**: `{id}-{release}-druid-msk-sa`

**Namespace**: `api`

**Example**: `fff-streaming-druid-msk-sa`

### IAM Role and Policy

**Role Name**: `{id}-{release}-druid-msk-sa`

**Custom Policy**: MSK Cluster Access

**Policy Configuration**:
```yaml
- name: {id}-{release}-druid-cluster-access
  policy: policy/msk-cluster-access.mustache
  mappings:
    topics:
      - arn:aws:kafka:{region}:{account}:topic/{id}-{release}-druid-msk/*
    clusters:
      - arn:aws:kafka:{region}:{account}:cluster/{id}-{release}-druid-msk/*
    groups:
      - arn:aws:kafka:{region}:{account}:group/{id}-{release}-druid-msk/*
```

**Permissions Granted**:

**Cluster Operations**:
```json
{
  "Effect": "Allow",
  "Action": [
    "kafka-cluster:Connect",
    "kafka-cluster:DescribeCluster",
    "kafka-cluster:AlterCluster"
  ],
  "Resource": "arn:aws:kafka:us-west-2:000000000000:cluster/fff-streaming-druid-msk/*"
}
```

**Topic Operations**:
```json
{
  "Effect": "Allow",
  "Action": [
    "kafka-cluster:CreateTopic",
    "kafka-cluster:DeleteTopic",
    "kafka-cluster:DescribeTopic",
    "kafka-cluster:AlterTopic",
    "kafka-cluster:ReadData",
    "kafka-cluster:WriteData"
  ],
  "Resource": "arn:aws:kafka:us-west-2:000000000000:topic/fff-streaming-druid-msk/*"
}
```

**Consumer Group Operations**:
```json
{
  "Effect": "Allow",
  "Action": [
    "kafka-cluster:AlterGroup",
    "kafka-cluster:DescribeGroup"
  ],
  "Resource": "arn:aws:kafka:us-west-2:000000000000:group/fff-streaming-druid-msk/*"
}
```

## Druid Kafka Ingestion

### Kafka Indexing Service Extension

**Druid Extension**: `druid-kafka-indexing-service`

**Loaded in runtime configuration**:
```properties
druid.extensions.loadList=["druid-kafka-indexing-service", ...]
```

### Supervisor Configuration

**Example Kafka Supervisor**:
```json
{
  "type": "kafka",
  "spec": {
    "dataSchema": {
      "dataSource": "events",
      "timestampSpec": {
        "column": "timestamp",
        "format": "iso"
      },
      "dimensionsSpec": {
        "dimensions": [
          "user_id",
          "event_type",
          "device",
          "country"
        ]
      },
      "metricsSpec": [
        {
          "type": "count",
          "name": "count"
        },
        {
          "type": "longSum",
          "name": "value_sum",
          "fieldName": "value"
        }
      ],
      "granularitySpec": {
        "segmentGranularity": "hour",
        "queryGranularity": "minute",
        "rollup": true
      }
    },
    "ioConfig": {
      "topic": "events",
      "consumerProperties": {
        "bootstrap.servers": "b-1.fff-streaming-druid-msk.abc123.kafka.us-west-2.amazonaws.com:9092,b-2.fff-streaming-druid-msk.abc123.kafka.us-west-2.amazonaws.com:9092,b-3.fff-streaming-druid-msk.abc123.kafka.us-west-2.amazonaws.com:9092",
        "security.protocol": "SSL"
      },
      "taskCount": 3,
      "replicas": 2,
      "taskDuration": "PT1H",
      "useEarliestOffset": false
    },
    "tuningConfig": {
      "type": "kafka",
      "maxRowsInMemory": 100000,
      "maxBytesInMemory": 134217728,
      "maxRowsPerSegment": 5000000,
      "intermediatePersistPeriod": "PT10M"
    }
  }
}
```

### Key Configuration Parameters

**DataSchema**:
- **timestampSpec**: Defines timestamp column and format
- **dimensionsSpec**: Defines dimensions (filterable columns)
- **metricsSpec**: Defines aggregations (count, sum, min, max)
- **granularitySpec**: Segment and query granularity

**IOConfig**:
- **topic**: Kafka topic name
- **bootstrap.servers**: MSK broker endpoints
- **taskCount**: Number of parallel ingestion tasks
- **replicas**: Replication for HA
- **taskDuration**: How long each task runs before handoff

**TuningConfig**:
- **maxRowsInMemory**: Trigger persist when reached
- **maxBytesInMemory**: Memory limit before persist
- **maxRowsPerSegment**: Maximum rows per segment
- **intermediatePersistPeriod**: Periodic persist interval

## Bootstrap Servers

### Getting MSK Bootstrap Servers

The MSK cluster provides bootstrap server endpoints:

**Stack Output**:
```yaml
DruidKafkaBootstrapServers:
  Value: b-1.fff-streaming-druid-msk.abc123.kafka.us-west-2.amazonaws.com:9092,b-2.fff-streaming-druid-msk.abc123.kafka.us-west-2.amazonaws.com:9092,b-3.fff-streaming-druid-msk.abc123.kafka.us-west-2.amazonaws.com:9092
  Export: {stackName}-DruidKafkaBootstrapServers
```

**AWS CLI**:
```bash
aws kafka get-bootstrap-brokers \
  --cluster-arn arn:aws:kafka:us-west-2:000000000000:cluster/fff-streaming-druid-msk/abc123
```

**Output**:
```json
{
  "BootstrapBrokerStringTls": "b-1.fff-streaming-druid-msk.abc123.kafka.us-west-2.amazonaws.com:9094,b-2.fff-streaming-druid-msk.abc123.kafka.us-west-2.amazonaws.com:9094,b-3.fff-streaming-druid-msk.abc123.kafka.us-west-2.amazonaws.com:9094",
  "BootstrapBrokerString": "b-1.fff-streaming-druid-msk.abc123.kafka.us-west-2.amazonaws.com:9092,b-2.fff-streaming-druid-msk.abc123.kafka.us-west-2.amazonaws.com:9092,b-3.fff-streaming-druid-msk.abc123.kafka.us-west-2.amazonaws.com:9092"
}
```

**Ports**:
- **9092**: Plaintext (not recommended)
- **9094**: TLS encryption (recommended)
- **9096**: SASL/SCRAM (if configured)

## Creating Topics

### Using Kafka CLI from EKS Pod

**1. Create a Kafka client pod**:
```bash
kubectl run kafka-client -n druid \
  --image=public.ecr.aws/bitnami/kafka:latest \
  --rm -it --restart=Never -- bash
```

**2. Create topic**:
```bash
kafka-topics.sh --create \
  --bootstrap-server b-1.fff-streaming-druid-msk.abc123.kafka.us-west-2.amazonaws.com:9092 \
  --topic events \
  --partitions 3 \
  --replication-factor 2
```

**3. List topics**:
```bash
kafka-topics.sh --list \
  --bootstrap-server b-1.fff-streaming-druid-msk.abc123.kafka.us-west-2.amazonaws.com:9092
```

**4. Describe topic**:
```bash
kafka-topics.sh --describe \
  --bootstrap-server b-1.fff-streaming-druid-msk.abc123.kafka.us-west-2.amazonaws.com:9092 \
  --topic events
```

### Using AWS CLI

**Create topic**:
```bash
aws kafka create-topic \
  --cluster-arn arn:aws:kafka:us-west-2:000000000000:cluster/fff-streaming-druid-msk/abc123 \
  --topic-name events \
  --number-of-partitions 3 \
  --replication-factor 2
```

## Producing Test Data

### Using Kafka Console Producer

```bash
# From kafka-client pod
kafka-console-producer.sh \
  --bootstrap-server b-1.fff-streaming-druid-msk.abc123.kafka.us-west-2.amazonaws.com:9092 \
  --topic events
```

**Sample messages** (JSON format):
```json
{"timestamp":"2024-01-15T10:00:00Z","user_id":"user123","event_type":"click","device":"mobile","country":"US","value":1}
{"timestamp":"2024-01-15T10:00:01Z","user_id":"user456","event_type":"view","device":"desktop","country":"UK","value":1}
{"timestamp":"2024-01-15T10:00:02Z","user_id":"user789","event_type":"purchase","device":"mobile","country":"CA","value":99}
```

### Using Python Producer

```python
from kafka import KafkaProducer
import json
from datetime import datetime

producer = KafkaProducer(
    bootstrap_servers='b-1.fff-streaming-druid-msk.abc123.kafka.us-west-2.amazonaws.com:9092',
    value_serializer=lambda v: json.dumps(v).encode('utf-8'),
    security_protocol='SSL'
)

event = {
    "timestamp": datetime.utcnow().isoformat() + "Z",
    "user_id": "user123",
    "event_type": "click",
    "device": "mobile",
    "country": "US",
    "value": 1
}

producer.send('events', event)
producer.flush()
```

## Monitoring MSK

### CloudWatch Metrics

**Automatically collected**:
- Broker CPU utilization
- Disk usage per broker
- Network throughput
- Active connections
- Messages per second
- Bytes in/out per second

**Access metrics**:
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Kafka \
  --metric-name BytesInPerSec \
  --dimensions Name=ClusterName,Value=fff-streaming-druid-msk \
  --start-time 2024-01-15T00:00:00Z \
  --end-time 2024-01-15T23:59:59Z \
  --period 3600 \
  --statistics Average
```

### Grafana Dashboards

The Grafana k8s-monitoring chart can scrape MSK metrics:

**JMX Exporter** (if enabled on brokers):
- Topic metrics
- Partition metrics
- Consumer lag
- Producer metrics

## Consumer Lag Monitoring

### Check Druid Ingestion Lag

**Via Druid API**:
```bash
curl -k -u admin:password \
  https://localhost:8888/druid/indexer/v1/supervisor/events/status
```

**Response includes**:
```json
{
  "id": "events",
  "state": "RUNNING",
  "payload": {
    "dataSource": "events",
    "stream": "events",
    "partitions": 3,
    "replicas": 2,
    "lag": {
      "0": 0,
      "1": 150,
      "2": 0
    },
    "aggregateLag": 150
  }
}
```

**Lag values**:
- **0**: Fully caught up
- **> 0**: Number of messages behind
- Monitor `aggregateLag` for overall health

## Resource Tagging

MSK cluster resources are tagged:

```yaml
tags:
  "{domain}:resource-type": msk
  "{domain}:category": compute
  "{domain}:type": streaming
  "{domain}:component": {id}-{release}-druid-msk
  "{domain}:part-of": "{organization}.{name}.{alias}"
```

**Example**:
```yaml
tags:
  "data.stxkxs.io:resource-type": msk
  "data.stxkxs.io:category": compute
  "data.stxkxs.io:type": streaming
  "data.stxkxs.io:component": fff-streaming-druid-msk
  "data.stxkxs.io:part-of": data.analytics.eks
```

## Troubleshooting

### Connection Issues

**Check security groups**:
```bash
aws ec2 describe-security-groups \
  --filters Name=tag:Name,Values=*msk*
```

**Verify pod can reach brokers**:
```bash
kubectl run -n druid test-kafka --image=busybox --rm -it --restart=Never -- \
  nc -zv b-1.fff-streaming-druid-msk.abc123.kafka.us-west-2.amazonaws.com 9092
```

### Ingestion Not Starting

**Check Druid supervisor**:
```bash
curl -k -u admin:password \
  https://localhost:8888/druid/indexer/v1/supervisor
```

**Check task logs**:
```bash
kubectl logs -n druid <middlemanager-pod> -c druid
```

### High Consumer Lag

**Possible causes**:
1. Insufficient MiddleManager resources
2. Too few ingestion tasks
3. Complex aggregations slowing ingestion
4. Network issues between MSK and EKS

**Solutions**:
1. Increase `taskCount` in supervisor
2. Scale up MiddleManager pods
3. Optimize segment granularity
4. Check VPC routing and security groups

## Next Steps

- [Apache Druid Deployment →](druid.md)
- [Grafana Observability →](grafana.md)
- [VPC Configuration →](vpc.md)
- [EKS Cluster →](eks.md)
