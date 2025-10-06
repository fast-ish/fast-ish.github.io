# Architecture Comparison

## Executive Summary

|  | **Druid Architecture** | **WebApp Architecture** |
|--|----------------------|------------------------|
| **Best For** | Real-time analytics, OLAP queries | Web/mobile app backends |
| **Compute Model** | Always-on EKS cluster | Serverless Lambda |
| **Starting Cost** | ~$200/month | ~$5/month |
| **Production Cost** | $500-2000/month | $100-1000/month |
| **Query Latency** | < 100ms (P95) | 50-500ms |
| **Cold Starts** | None | 1-2 seconds |
| **Scaling** | Minutes (Karpenter) | Instant (automatic) |
| **Operational Complexity** | Medium | Low |
| **Deployment Time** | 40-60 minutes | 20-30 minutes |

## Infrastructure Components

### Compute Layer

| Component | Druid | WebApp |
|-----------|-------|--------|
| **Container Orchestration** | Amazon EKS 1.33 | N/A |
| **Serverless Functions** | N/A | AWS Lambda |
| **Minimum Nodes** | 2 (t3.medium) | 0 |
| **Auto Scaling** | Karpenter | Automatic |
| **Operating System** | Bottlerocket | Managed by AWS |
| **Runtime Environment** | JVM (Druid) | Node.js/Python/Java |

### Data Storage

| Component | Druid | WebApp |
|-----------|-------|--------|
| **Primary Database** | RDS PostgreSQL (metadata) | DynamoDB |
| **Data Model** | Column-oriented segments | Key-value (NoSQL) |
| **Deep Storage** | S3 (immutable segments) | N/A |
| **Temp Storage** | S3 (MSQ queries) | Lambda /tmp (512MB-10GB) |
| **Capacity Model** | Provisioned (RDS) + S3 | On-demand (DynamoDB) |

### Networking

| Component | Druid | WebApp |
|-----------|-------|--------|
| **VPC CIDR** | 10.0.0.0/16 | 192.168.0.0/16 |
| **Availability Zones** | 3 | 3 |
| **NAT Gateways** | 2 | 2 |
| **Public Subnets** | 3x /24 | 3x /24 |
| **Private Subnets** | 3x /24 | 3x /24 |
| **Load Balancer** | ALB/NLB (optional) | API Gateway |

### Authentication & Authorization

| Component | Druid | WebApp |
|-----------|-------|--------|
| **User Authentication** | Not included* | Cognito User Pool ✅ |
| **Service Authentication** | IRSA (EKS) | IAM roles (Lambda) |
| **API Authorization** | Custom (if exposed) | Cognito JWT authorizer |
| **MFA Support** | N/A | TOTP, SMS ✅ |
| **SSO Integration** | N/A | SAML, OIDC ✅ |

*Can be added via custom implementation or API Gateway in front of Druid

### Messaging & Streaming

| Component | Druid | WebApp |
|-----------|-------|--------|
| **Stream Processing** | MSK Serverless ✅ | Not included* |
| **Message Queue** | N/A | Not included* |
| **Event Bus** | N/A | Not included* |
| **Ingestion** | Real-time (Kafka) | API Gateway (sync) |

*Can be added via SQS, SNS, Kinesis, or MSK

### Email Service

| Component | Druid | WebApp |
|-----------|-------|--------|
| **Email Provider** | Not included* | SES ✅ |
| **Email Templates** | N/A | Lambda triggers ✅ |
| **Domain Setup** | N/A | Automated (Route 53) |
| **DKIM/SPF** | N/A | Automated ✅ |

*Can be added via SES

## Observability

### Monitoring

| Feature | Druid | WebApp |
|---------|-------|--------|
| **Metrics** | Grafana Cloud (Prometheus) | CloudWatch Metrics |
| **Logs** | Grafana Cloud (Loki) | CloudWatch Logs |
| **Traces** | Grafana Cloud (Tempo) | X-Ray |
| **Profiles** | Grafana Cloud (Pyroscope) | Not included |
| **Dashboards** | Pre-built Grafana | Custom CloudWatch |
| **Alerts** | Grafana Alerting | CloudWatch Alarms |
| **Log Retention** | 30 days (Grafana Cloud free tier) | Configurable (CloudWatch) |

### Container Insights

| Feature | Druid | WebApp |
|---------|-------|--------|
| **Container Insights** | ✅ Enabled | N/A |
| **Pod Metrics** | ✅ CPU, Memory, Network | N/A |
| **Cluster Metrics** | ✅ Node utilization | N/A |
| **Control Plane Logs** | ✅ API, Audit, Controller | N/A |

## Performance Characteristics

### Query Performance

| Metric | Druid | WebApp |
|--------|-------|--------|
| **P50 Latency** | < 50ms | 50-100ms |
| **P95 Latency** | < 200ms | 100-300ms |
| **P99 Latency** | < 500ms | 300-1000ms |
| **Cold Start** | None | 500-2000ms |
| **Warm Requests** | Always warm | After 1st request |
| **Max Concurrency** | 1000+ QPS (cluster-dependent) | 1000 concurrent (default quota) |

### Data Ingestion

| Metric | Druid | WebApp |
|--------|-------|--------|
| **Ingestion Method** | Kafka streaming | API requests |
| **Throughput** | 100K+ events/sec | N/A (request-based) |
| **Latency** | < 1 second (streaming) | N/A |
| **Batch Support** | ✅ MSQ (Multi-Stage Query) | N/A |

### Database Performance

| Metric | Druid (RDS) | WebApp (DynamoDB) |
|--------|-------------|-------------------|
| **Read Latency** | 5-20ms | < 10ms (P99) |
| **Write Latency** | 10-50ms | < 20ms (P99) |
| **Transactions** | ✅ ACID | ❌ (single-item atomic) |
| **Joins** | ✅ SQL | ❌ (denormalize) |
| **Indexing** | ✅ B-tree, indexes | ✅ LSI, GSI |

## Scalability

### Horizontal Scaling

| Capability | Druid | WebApp |
|------------|-------|--------|
| **Compute Scaling** | Karpenter (minutes) | Automatic (instant) |
| **Database Scaling** | Manual (RDS read replicas) | Automatic (on-demand) |
| **Storage Scaling** | Automatic (S3) | Automatic (DynamoDB) |
| **Max Scale** | Cluster size (100s of nodes) | AWS service limits |

### Vertical Scaling

| Capability | Druid | WebApp |
|------------|-------|--------|
| **Node Size** | Manual (change instance type) | N/A |
| **Lambda Memory** | N/A | Configurable (128MB-10GB) |
| **Database Size** | Manual (RDS instance type) | Automatic |

## Cost Structure

### Fixed Costs (Always Running)

| Component | Druid | WebApp |
|-----------|-------|--------|
| **EKS Control Plane** | $73/month | N/A |
| **Minimum EC2** | ~$60/month (2x t3.medium) | N/A |
| **RDS Minimum** | ~$15/month (db.t3.micro) | N/A |
| **NAT Gateway** | ~$65/month (2 gateways) | ~$65/month (2 gateways) |
| **Total Minimum** | **~$200/month** | **~$65/month*** |

*WebApp NAT only if Lambda needs internet access; can be $0 with VPC endpoints

### Variable Costs (Usage-Based)

| Component | Druid | WebApp |
|-----------|-------|--------|
| **Compute** | EC2 hours (predictable) | Lambda GB-seconds (variable) |
| **API Requests** | N/A | $3.50 per 1M requests |
| **Database** | RDS IOPS, storage | DynamoDB read/write units |
| **Streaming** | MSK (GB ingested) | N/A |
| **Data Transfer** | GB out (~$0.09/GB) | GB out (~$0.09/GB) |

### Cost Optimization

**Druid:**
- Use Spot instances for Historical nodes (50-70% savings)
- Karpenter node consolidation
- S3 Intelligent-Tiering for deep storage
- Reserved RDS instances (40% savings)

**WebApp:**
- Lambda provisioned concurrency (only if needed)
- DynamoDB reserved capacity (for predictable load)
- API Gateway caching (reduce Lambda invocations)
- VPC endpoints (avoid NAT charges)

## Operational Requirements

### Prerequisites

| Requirement | Druid | WebApp |
|-------------|-------|--------|
| **Java** | ✅ Java 21 | ✅ Java 21 |
| **Maven** | ✅ 3.8+ | ✅ 3.8+ |
| **AWS CLI** | ✅ Configured | ✅ Configured |
| **CDK CLI** | ✅ Installed | ✅ Installed |
| **Kubectl** | ✅ Required | ❌ Not needed |
| **Helm** | ✅ Knowledge helpful | ❌ Not needed |
| **Grafana Account** | ✅ Required | ❌ Not needed |
| **Domain (Route 53)** | ❌ Optional | ✅ Required (for SES) |

### Operational Tasks

| Task | Druid | WebApp |
|------|-------|--------|
| **Cluster Upgrades** | ✅ EKS version upgrades | N/A |
| **Node Patching** | ✅ Automated (Bottlerocket) | N/A |
| **Druid Upgrades** | ✅ Helm chart updates | N/A |
| **Lambda Updates** | N/A | ✅ Deploy new code |
| **Database Backups** | ✅ RDS automated snapshots | ✅ DynamoDB PITR |
| **Certificate Rotation** | ✅ cert-manager | N/A |
| **Log Retention** | ✅ Configure Loki/CW | ✅ Configure CloudWatch |

### Disaster Recovery

| Capability | Druid | WebApp |
|------------|-------|--------|
| **Backup Strategy** | RDS snapshots + S3 versioning | DynamoDB PITR + export |
| **RTO (Recovery Time)** | 1-2 hours (restore RDS + redeploy) | 30-60 minutes (redeploy) |
| **RPO (Point-in-Time)** | 5 minutes (RDS PITR) | 1 second (DynamoDB PITR) |
| **Multi-Region** | Manual setup | Manual setup |
| **Data Replication** | S3 cross-region replication | DynamoDB global tables |

## Security Features

### Data Encryption

| Feature | Druid | WebApp |
|---------|-------|--------|
| **At Rest** | ✅ EBS (KMS), RDS (KMS), S3 | ✅ DynamoDB (default), S3 |
| **In Transit** | ✅ TLS (EKS), HTTPS | ✅ HTTPS (API Gateway) |
| **Key Management** | ✅ AWS KMS | ✅ AWS KMS |

### Network Security

| Feature | Druid | WebApp |
|---------|-------|--------|
| **Private Subnets** | ✅ EKS nodes | ✅ Lambda functions |
| **Security Groups** | ✅ Fine-grained | ✅ Lambda SG |
| **NACLs** | ✅ Supported | ✅ Supported |
| **WAF Integration** | ✅ ALB (optional) | ✅ API Gateway |

### Identity & Access

| Feature | Druid | WebApp |
|---------|-------|--------|
| **IAM Roles** | ✅ IRSA (pod-level) | ✅ Lambda execution role |
| **Secrets Management** | ✅ Secrets Manager + CSI | ✅ Secrets Manager |
| **Audit Logging** | ✅ CloudTrail, EKS audit | ✅ CloudTrail |

## Use Case Examples

### Druid Architecture - Ideal Scenarios

**1. Real-Time Analytics Dashboard**
- Ingesting 1M events/sec from IoT devices
- Sub-second query response for dashboards
- 500 concurrent users running ad-hoc queries
- **Cost**: ~$1500/month
- **Latency**: < 200ms P95

**2. Clickstream Analysis**
- Kafka streaming from web/mobile apps
- Complex aggregations (funnels, cohorts)
- Time-series rollups (hourly, daily)
- **Cost**: ~$800/month
- **Retention**: 90 days hot, unlimited cold (S3)

**3. Application Performance Monitoring**
- Distributed tracing ingestion
- Real-time alerting on anomalies
- Historical performance analysis
- **Cost**: ~$1200/month
- **Queries**: 2000+ QPS

### WebApp Architecture - Ideal Scenarios

**1. SaaS Application Backend**
- User registration and authentication
- Subscription management (free/paid tiers)
- RESTful API for mobile/web clients
- **Cost**: ~$150/month (10K users)
- **Latency**: 100ms P95 (warm)

**2. Content Membership Site**
- Cognito authentication with MFA
- User profiles in DynamoDB
- Email notifications via SES
- **Cost**: ~$75/month (5K users)
- **Features**: Built-in auth, email, API

**3. API-First Mobile App**
- Lambda-based REST API
- Real-time user data sync
- Push notification integration
- **Cost**: ~$200/month (50K requests/day)
- **Scaling**: Automatic, zero config

## Migration Considerations

### From Other Systems to Druid

**From Athena/Redshift:**
- ✅ Gain: Sub-second queries, streaming ingestion
- ⚠️ Trade-off: Higher fixed cost, operational complexity
- 📊 Break-even: ~500K queries/month

**From ElasticSearch:**
- ✅ Gain: Better compression, faster aggregations
- ⚠️ Trade-off: Less flexible text search
- 🔄 Consider: Druid for analytics, keep ES for search

### From Other Systems to WebApp

**From EC2 Monolith:**
- ✅ Gain: Auto-scaling, lower ops, pay-per-request
- ⚠️ Trade-off: 15-min Lambda timeout, cold starts
- 💰 Savings: 50-70% for variable traffic

**From Self-Managed Auth:**
- ✅ Gain: Managed Cognito, built-in MFA, compliance
- ⚠️ Trade-off: Vendor lock-in, Cognito pricing
- 🔐 Security: Better (managed service)

## Decision Checklist

### Choose Druid If:
- [ ] Need sub-second OLAP queries
- [ ] Ingesting streaming data (Kafka/Kinesis)
- [ ] High concurrent query volume (100+ QPS)
- [ ] Time-series data with historical analysis
- [ ] Budget allows ~$200+ base cost
- [ ] Team has Kubernetes experience

### Choose WebApp If:
- [ ] Building web/mobile application
- [ ] Need user authentication out-of-box
- [ ] Variable traffic patterns
- [ ] Prefer serverless (no infra management)
- [ ] Budget-sensitive (< $100/month for MVP)
- [ ] Team has serverless experience

### Choose Both If:
- [ ] User-facing app + internal analytics
- [ ] Need authentication AND real-time dashboards
- [ ] Want to publish app events to analytics pipeline
- [ ] Building comprehensive platform

## Next Steps

- [Architecture Decisions →](decisions.md)
- [Scaling Guide →](scaling-guide.md)
- [Cost Optimization →](cost-optimization.md)
- [Druid Overview →](/druid/overview.md)
- [WebApp Overview →](/webapp/overview.md)
