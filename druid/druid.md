# Apache Druid Deployment

## Overview

Apache Druid is deployed on EKS using a Helm chart that configures all Druid components with AWS resource integration. The deployment includes metadata storage (RDS PostgreSQL), deep storage (S3), real-time ingestion (MSK Kafka), and complete observability.

## Helm Chart Configuration

### Chart Details

**Repository**: `oci://public.ecr.aws/q9l5h9b2/stxkxs.io/v1/helm/druid`

**Chart Name**: `druid`

**Version**: `0.1.0`

**Release Name**: Configurable via `hosted:eks:druid:release`
- Example: `streaming`

**Namespace**: `druid`

### How Configuration is Used

**Input (cdk.context.json)**:
```json
{
  "deployment:id": "fff",
  "deployment:eks:druid:release": "streaming",
  "deployment:account": "000000000000",
  "deployment:region": "us-west-2",
  "deployment:domain": "data.stxkxs.io"
}
```

**Template (druid section in conf.mustache)**:
```yaml
druid:
  access: druid/setup/access.mustache
  secrets: druid/setup/secrets.mustache
  storage: druid/setup/storage.mustache
  ingestion: druid/setup/ingestion.mustache
  chart:
    name: druid
    namespace: druid
    release: {{deployment:eks:druid:release}}  # streaming
    repository: oci://public.ecr.aws/q9l5h9b2/stxkxs.io/v1/helm/druid
    values: druid/values.mustache
    version: 0.1.0
```

**Generates Helm Release**:
```bash
helm install streaming oci://public.ecr.aws/q9l5h9b2/stxkxs.io/v1/helm/druid \
  --version 0.1.0 \
  --namespace druid \
  --values generated-values.yaml
```

## Docker Image

### Image Configuration

**Repository**: `public.ecr.aws/q9l5h9b2/stxkxs.io/v1/docker/druid`

**Tag**: `{{deployment:version}}` (e.g., `v1`)

**Pull Policy**: `Always`

**Configuration**:
```yaml
image:
  tag: "v1"
  repository: public.ecr.aws/q9l5h9b2/stxkxs.io/v1/docker/druid
  pullPolicy: Always
```

### Building Custom Image (Optional)

**Dockerfile**: `Dockerfile.druid` in repository root

**Build and push**:
```bash
# Create ECR repository
aws ecr create-repository \
  --repository-name stxkxs.io/v1/docker/druid \
  --region us-west-2 \
  --image-scanning-configuration scanOnPush=true

# Build for linux/amd64
docker buildx build --provenance=false --platform linux/amd64 \
  -f Dockerfile.druid \
  -t 000000000000.dkr.ecr.us-west-2.amazonaws.com/stxkxs.io/v1/docker/druid:v1 \
  -t 000000000000.dkr.ecr.us-west-2.amazonaws.com/stxkxs.io/v1/docker/druid:latest \
  --push .
```

## IAM Service Account (IRSA)

### Service Account

**Name**: `{id}-{release}-druid-sa`

**Example**: `fff-streaming-druid-sa`

**Namespace**: `druid`

### IAM Role and Policies

**Role Name**: `{id}-{release}-druid-sa`

**Custom Policies**:

**1. S3 Bucket Access**:
```yaml
- name: {id}-{release}-druid-bucket-access
  policy: policy/druid-bucket-access.mustache
  resources:
    - arn:aws:s3:::{id}-{release}-druid-indexlogs
    - arn:aws:s3:::{id}-{release}-druid-indexlogs/*
    - arn:aws:s3:::{id}-{release}-druid-deepstorage
    - arn:aws:s3:::{id}-{release}-druid-deepstorage/*
    - arn:aws:s3:::{id}-{release}-druid-msq
    - arn:aws:s3:::{id}-{release}-druid-msq/*
```

**Grants**:
- List, read, write, delete objects in index logs bucket
- List, read, write, delete objects in deep storage bucket
- List, read, write, delete objects in MSQ bucket

**2. Secrets Manager Access**:
```yaml
- name: {id}-{release}-druid-secret-access
  policy: policy/secret-access.mustache
  resources:
    - arn:aws:secretsmanager:{region}:{account}:secret:{id}-{release}-druid-tls*
    - arn:aws:secretsmanager:{region}:{account}:secret:{id}-{release}-druid-admin*
    - arn:aws:secretsmanager:{region}:{account}:secret:{id}-{release}-druid-system*
    - arn:aws:secretsmanager:{region}:{account}:secret:{id}-{release}-druid-metadata*
```

**Grants**:
- GetSecretValue for TLS certificates
- GetSecretValue for admin credentials
- GetSecretValue for system credentials
- GetSecretValue for metadata database credentials

**3. EBS Volume Management**:
```yaml
- name: {id}-{release}-druid-manage-volume
  policy: policy/manage-volume.mustache
  resources:
    - arn:aws:ec2:{region}:{account}:volume/*
    - arn:aws:ec2:{region}:{account}:instance/*
```

**Grants**:
- Attach/detach EBS volumes
- Create/delete volumes
- Required for persistent storage

**4. MSK Cluster Access**:
```yaml
- name: {id}-{release}-druid-msk-cluster-access
  policy: policy/msk-cluster-access.mustache
  resources:
    topics:
      - arn:aws:kafka:{region}:{account}:topic/{id}-{release}-druid-msk/*
    clusters:
      - arn:aws:kafka:{region}:{account}:cluster/{id}-{release}-druid-msk/*
    groups:
      - arn:aws:kafka:{region}:{account}:group/{id}-{release}-druid-msk/*
```

**Grants**:
- Connect to MSK cluster
- Read/write Kafka topics
- Join consumer groups

## Druid Runtime Configuration

### Core Extensions

**Loaded Extensions**:
```properties
druid.extensions.loadList=[
  "simple-client-sslcontext",           # TLS support
  "druid-basic-security",               # Authentication/authorization
  "druid-s3-extensions",                # S3 deep storage
  "druid-aws-rds-extensions",           # RDS metadata storage
  "postgresql-metadata-storage",        # PostgreSQL driver
  "druid-multi-stage-query",            # MSQ engine
  "druid-kafka-indexing-service",       # Kafka ingestion
  "prometheus-emitter",                 # Prometheus metrics
  "druid-kubernetes-extensions",        # K8s discovery
  "druid-kubernetes-overlord-extensions" # K8s task execution
]
```

### Authentication & Authorization

**Basic Auth Configuration**:
```properties
druid.auth.authenticatorChain=["authn-{hosted:id}"]
druid.auth.authenticator.authn-{hosted:id}.type=basic
druid.auth.authenticator.authn-{hosted:id}.credentialsValidator.type=metadata
druid.auth.authenticator.authn-{hosted:id}.authorizerName=authz-{hosted:id}

# Admin user password from environment variable
druid.auth.authenticator.authn-{hosted:id}.initialAdminPassword=${env:DRUID_ADMIN_PASSWORD}

# System user for internal communication
druid.escalator.type=basic
druid.escalator.authorizerName=authz-{hosted:id}
druid.escalator.internalClientUsername=${env:DRUID_SYSTEM_USERNAME}
druid.escalator.internalClientPassword=${env:DRUID_SYSTEM_PASSWORD}
```

**Environment Variables** (from Secrets Manager):
- `DRUID_ADMIN_PASSWORD` - Admin user password
- `DRUID_SYSTEM_USERNAME` - Internal system username
- `DRUID_SYSTEM_PASSWORD` - Internal system password

### TLS Configuration

**TLS Settings**:
```properties
druid.enableTlsPort=true
druid.enablePlaintextPort=false

# Server keystore
druid.server.https.keyStorePath=/opt/druid/conf/druid/cluster/tls/server-keystore.p12
druid.server.https.keyStoreType=pkcs12
druid.server.https.certAlias=druid-server
druid.server.https.keyStorePassword=changeit
druid.server.https.requestClientCertificate=true

# Server truststore
druid.server.https.trustStoreType=pkcs12
druid.server.https.trustStorePath=/opt/druid/conf/druid/cluster/tls/server-truststore.p12
druid.server.https.trustStorePassword=changeit

# Client keystore
druid.client.https.keyStorePath=/opt/druid/conf/druid/cluster/tls/client-keystore.p12
druid.client.https.keyStoreType=pkcs12
druid.client.https.certAlias=druid-client
druid.client.https.keyStorePassword=changeit
druid.client.https.protocol=TLSv1.2

# Client truststore
druid.client.https.trustStoreType=pkcs12
druid.client.https.trustStorePath=/opt/druid/conf/druid/cluster/tls/client-truststore.p12
druid.client.https.trustStorePassword=changeit
```

**TLS Certificates** (from Secrets Manager):
- Server keystore: `{id}-{release}-druid-tls/server-keystore.p12`
- Server truststore: `{id}-{release}-druid-tls/server-truststore.p12`
- Client keystore: `{id}-{release}-druid-tls/client-keystore.p12`
- Client truststore: `{id}-{release}-druid-tls/client-truststore.p12`

### Kubernetes Discovery (ZooKeeper-less)

**Configuration**:
```properties
druid.discovery.type=k8s
druid.zk.service.enabled=false
druid.discovery.k8s.clusterIdentifier={hosted:id}
```

**What it does**:
- Uses Kubernetes API for service discovery
- Eliminates need for ZooKeeper
- Druid components find each other via K8s services
- Simpler operational model

### Metadata Storage (RDS PostgreSQL)

**Configuration**:
```properties
druid.metadata.storage.type=postgresql
druid.metadata.storage.connector.user=${env:DRUID_METADATA_STORAGE_USERNAME}
druid.metadata.storage.connector.password=${env:DRUID_METADATA_STORAGE_PASSWORD}
druid.metadata.storage.connector.connectURI=jdbc:postgresql://${env:DRUID_METADATA_STORAGE_HOST}/druid_metadata
druid.metadata.storage.connector.createTables=true
```

**Database Tables**:
- `druid` - Base table
- `druid_audit` - Audit logs
- `druid_data_source` - Datasource metadata
- `druid_pending_segments` - Pending segment info
- `druid_segments` - Segment metadata
- `druid_rules` - Retention rules
- `druid_config` - Configuration
- `druid_tasks` - Task metadata
- `druid_task_logs` - Task logs
- `druid_task_locks` - Task locking
- `druid_supervisors` - Supervisor configs

**Environment Variables** (from Secrets Manager):
- `DRUID_METADATA_STORAGE_USERNAME` - Database username
- `DRUID_METADATA_STORAGE_PASSWORD` - Database password
- `DRUID_METADATA_STORAGE_HOST` - RDS endpoint

### Deep Storage (S3)

**Configuration**:
```properties
druid.storage.type=s3
druid.storage.disableAcl=true
druid.storage.baseKey=druid/segments
druid.storage.bucket={id}-{release}-druid-deepstorage
```

**What it stores**:
- Immutable data segments
- Long-term data retention
- Compressed columnar format

**S3 Bucket**: `{id}-{release}-druid-deepstorage`
- Example: `fff-streaming-druid-deepstorage`

### Index Logs Storage (S3)

**Configuration**:
```properties
druid.indexer.logs.type=s3
druid.indexer.logs.disableAcl=true
druid.indexer.logs.s3Prefix=druid/indexing-logs
druid.indexer.logs.s3Bucket={id}-{release}-druid-indexlogs
```

**What it stores**:
- Indexing task logs
- Debugging information
- Temporary retention (1 day lifecycle)

**S3 Bucket**: `{id}-{release}-druid-indexlogs`
- Example: `fff-streaming-druid-indexlogs`

### Multi-Stage Query Storage (S3)

**Configuration**:
```properties
druid.msq.intermediate.storage.enable=true
druid.msq.intermediate.storage.tempDir=/var/druid/msq
druid.msq.intermediate.storage.cleaner.enabled=true
druid.msq.intermediate.storage.type=s3
druid.msq.intermediate.storage.prefix=druid/msq
druid.msq.intermediate.storage.bucket={id}-{release}-druid-msq
```

**What it stores**:
- Intermediate data for multi-stage queries
- Temporary shuffled data
- Short retention (1 day lifecycle)

**S3 Bucket**: `{id}-{release}-druid-msq`
- Example: `fff-streaming-druid-msq`

## Monitoring & Observability

### Prometheus Metrics

**Configuration**:
```properties
druid.emitter=composing
druid.emitter.composing.emitters=["logging","prometheus"]
druid.emitter.prometheus.port=9000
druid.emitter.prometheus.strategy=exporter
druid.emitter.prometheus.addHostAsLabel=true
druid.emitter.prometheus.addServiceAsLabel=true
```

**Metrics Endpoint**: `http://pod-ip:9000/metrics`

**Pod Annotations**:
```yaml
annotations:
  "k8s.grafana.com/scrape": "true"
  "k8s.grafana.com/metrics.portNumber": "9000"
```

**Metrics Exposed**:
- Query latencies (P50, P95, P99)
- Segment counts and sizes
- JVM heap usage
- GC pauses
- Ingestion lag
- Task success/failure rates

## Security Context

**Pod Security**:
```yaml
securityContext:
  fsGroup: 1000
  runAsUser: 1000
  runAsGroup: 1000
```

**What it does**:
- Runs Druid processes as non-root user (UID 1000)
- Sets file ownership to group 1000
- Follows security best practices

## Resource Tagging

All Druid resources are tagged:

```yaml
labels:
  "{domain}/resource-type": druid-helm-chart
  "{domain}/category": compute.storage
  "{domain}/type": analytics
  "{domain}/id": "{id}"
  "{domain}/name": "{name}"
  "{domain}/billing": "{organization}"
  "{domain}/part-of": "{organization}.{name}.{alias}"
```

**Example**:
```yaml
labels:
  "data.stxkxs.io/resource-type": druid-helm-chart
  "data.stxkxs.io/category": compute.storage
  "data.stxkxs.io/type": analytics
  "data.stxkxs.io/id": "fff"
  "data.stxkxs.io/name": "analytics"
  "data.stxkxs.io/billing": "data"
  "data.stxkxs.io/part-of": "data.analytics.eks"
```

## Accessing Druid

### Port Forward to Router

```bash
kubectl port-forward -n druid svc/druid-router 8888:8888
```

### Access Web Console

Open browser to: `https://localhost:8888`

**Login**:
- Username: `admin`
- Password: From `DRUID_ADMIN_PASSWORD` secret

### Query with curl

```bash
# Get datasources
curl -k -u admin:password https://localhost:8888/druid/coordinator/v1/datasources

# Submit query
curl -k -u admin:password \
  -X POST \
  -H 'Content-Type: application/json' \
  -d '{
    "query": "SELECT * FROM my_datasource LIMIT 10"
  }' \
  https://localhost:8888/druid/v2/sql
```

## Druid Components

The Helm chart deploys these Druid components:

### Coordinator
- Manages segment distribution
- Balances segments across historicals
- Enforces retention rules

### Overlord
- Manages indexing tasks
- Distributes work to MiddleManagers
- Task scheduling and monitoring

### Broker
- Routes queries to data nodes
- Merges results
- Query caching

### Historical
- Serves immutable segments
- Loads data from deep storage (S3)
- Main query processing

### MiddleManager
- Executes ingestion tasks
- Creates new segments
- Hands off to historicals

### Router
- API gateway
- Routes to appropriate broker
- Load balancing

## Next Steps

- [MSK Integration →](msk.md)
- [Grafana Observability →](grafana.md)
- [VPC Configuration →](vpc.md)
- [EKS Cluster →](eks.md)
