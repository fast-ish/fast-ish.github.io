# Changelog

All notable changes to Fastish infrastructure projects are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- Additional EKS add-on support (external-dns, metrics-server)
- Multi-region deployment patterns
- AWS Organizations integration for multi-account deployments

---

## [1.0.0] - 2024-01

Initial public release of the Fastish infrastructure platform.

### Added

#### Platform Documentation
- Comprehensive documentation hub at [fast-ish.github.io](https://fast-ish.github.io)
- Usage examples covering 8 deployment scenarios (modernization to AI/ML)
- Glossary with 80+ terms and acronyms
- Troubleshooting guide with common issues and resolutions
- Network requirements documentation
- IAM permissions reference
- Capacity planning guide
- Upgrade and migration procedures

#### aws-webapp-infra v1.0.0
- VPC with public/private subnets across 2 Availability Zones
- Amazon Cognito user pool with email verification
- Amazon DynamoDB tables with on-demand billing
- Amazon SES domain and email identity with DKIM
- Amazon API Gateway REST API with Cognito authorizer
- AWS Lambda functions with VPC integration
- CloudFormation nested stack architecture

#### aws-eks-infra v1.0.0
- Amazon EKS cluster (Kubernetes 1.28+)
- AWS managed add-ons: VPC CNI, CoreDNS, kube-proxy, EBS CSI, Pod Identity Agent, CloudWatch Container Insights
- Helm chart add-ons: cert-manager, AWS Load Balancer Controller, Karpenter, CSI Secrets Store
- Managed node groups with Bottlerocket AMI
- Karpenter autoscaling with Spot instance support
- Grafana Cloud observability integration (Mimir, Loki, Tempo, Pyroscope)
- OpenTelemetry Collector for telemetry pipeline
- SQS queue for node interruption handling

#### aws-druid-infra v1.0.0
- Apache Druid deployment on EKS via Helm
- All Druid process types: Coordinator, Overlord, Broker, Router, Historical, MiddleManager
- Amazon RDS PostgreSQL for metadata storage
- Amazon S3 buckets for deep storage and MSQ scratch space
- Amazon MSK cluster for real-time Kafka ingestion
- Full EKS infrastructure (inherits from aws-eks-infra patterns)
- Grafana Cloud observability integration

#### cdk-common v1.0.0
- Mustache template processing with JMustache
- Jackson YAML configuration parsing
- Type-safe Java POJO configuration objects
- CDK constructs for 25+ AWS services:
  - Compute: Lambda, EKS
  - Storage: S3, EBS
  - Database: DynamoDB, RDS
  - Networking: VPC, API Gateway, ALB, NLB
  - Security: IAM, Cognito, KMS, Secrets Manager
  - Messaging: SQS, SNS, SES
  - Analytics: Athena, MSK, Kinesis
  - DevOps: CodeBuild, ECR, CodePipeline

### Security
- Private subnet isolation for all compute resources
- IAM least privilege policies
- KMS encryption at rest for RDS, S3, and EBS
- TLS 1.3 encryption in transit
- Bottlerocket AMI for minimal container attack surface
- VPC Flow Logs and CloudTrail audit logging
- Security group rules with minimal port exposure

### Documentation
- AWS Well-Architected Framework alignment documented
- DORA metrics impact analysis
- Mermaid.js architecture diagrams throughout
- AWS documentation references for all services
- Step-by-step deployment guides

---

## Version Compatibility Matrix

| Component | Version | AWS CDK | Java | Kubernetes | Druid |
|-----------|---------|---------|------|------------|-------|
| aws-webapp-infra | 1.0.0 | 2.221.0+ | 21+ | N/A | N/A |
| aws-eks-infra | 1.0.0 | 2.221.0+ | 21+ | 1.28+ | N/A |
| aws-druid-infra | 1.0.0 | 2.221.0+ | 21+ | 1.28+ | 28+ |
| cdk-common | 1.0.0 | 2.221.0+ | 21+ | N/A | N/A |

---

## Upgrade Notes

### From Pre-release to 1.0.0

This is the initial release. No upgrade path required.

For future upgrades, see the [Upgrade Guide](docs/UPGRADE.md) for detailed migration procedures.

---

## Deprecation Policy

- **Major versions**: Breaking changes may occur. Minimum 6-month notice.
- **Minor versions**: Backward compatible features and deprecation warnings.
- **Patch versions**: Backward compatible bug fixes only.

Deprecated features will be documented in this changelog with removal target versions.

---

## Links

- [Documentation](https://fast-ish.github.io)
- [aws-webapp-infra Repository](https://github.com/fast-ish/aws-webapp-infra)
- [aws-eks-infra Repository](https://github.com/fast-ish/aws-eks-infra)
- [aws-druid-infra Repository](https://github.com/fast-ish/aws-druid-infra)
- [cdk-common Repository](https://github.com/fast-ish/cdk-common)

---

**Last Updated**: 2024-01
