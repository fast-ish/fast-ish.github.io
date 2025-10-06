# fastish Documentation

Welcome to fastish - your AWS infrastructure automation service that helps you build cool stuff without the complexity.

## Overview: Infrastructure as Code with AWS CDK

In today's cloud landscape, teams spend more time wrestling with infrastructure complexity than building the features their customers need. We've developed a systematic approach to eliminate this friction - because the most valuable code is the code you never have to write.

Our AWS infrastructure automation service applies this principle alongside established engineering wisdom to dramatically accelerate your path from idea to production. By encoding infrastructure decisions into clear patterns using **AWS CDK** and **CloudFormation**, we help teams focus on what matters: delivering product value to their users.

fastish leverages the power of [AWS CDK (Cloud Development Kit)](https://aws.amazon.com/cdk/) to define cloud infrastructure using familiar programming languages. This approach, known as [Infrastructure as Code (IaC)](https://docs.aws.amazon.com/whitepapers/latest/introduction-devops-aws/infrastructure-as-code.html), enables teams to version control their infrastructure, apply software engineering best practices, and automate deployments with confidence. By combining AWS CDK with battle-tested design patterns from the [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/), we deliver infrastructure that is secure, reliable, performant, and cost-optimized from day one.

## What We Provide: AWS CDK Constructs for Modern Cloud Architecture

We build on AWS's proven blueprints to create comprehensive system architectures that scale. Our infrastructure is composed of modular, reusable **CDK constructs** that encapsulate cloud infrastructure best practices, allowing you to deploy production-ready environments in minutes rather than weeks:

### Multi-tenant SaaS Infrastructure (Cognito + DynamoDB + API Gateway)
Production-ready foundation layer that powers marketplace-ready applications with complete tenant isolation at the data, network, and application layers. Our multi-tenancy model implements row-level security in **DynamoDB**, tenant-scoped **API Gateway** authentication with **Cognito**, and isolated resource allocation to ensure data privacy and compliance with regulatory requirements like [GDPR](https://gdpr-info.eu/) and [HIPAA](https://www.hhs.gov/hipaa/index.html).

### Modern Frontend Stack (Next.js + AWS Amplify + CloudFront)
**[Next.js](https://nextjs.org/)** on **[AWS Amplify](https://aws.amazon.com/amplify/)** provides a powerful React-based frontend framework with automatic code splitting, server-side rendering (SSR), and static site generation (SSG) capabilities. Combined with our intelligent API layer built on **[Amazon API Gateway](https://aws.amazon.com/api-gateway/)**, you get automatic request throttling, tenant isolation through custom authorizers, and seamless integration with backend services. **CloudFront CDN** ensures global low-latency content delivery.

### Real-time Analytics Platform (Apache Druid + Amazon EKS + Kafka)
**[Apache Druid](https://druid.apache.org/)** on **[Amazon EKS (Elastic Kubernetes Service)](https://aws.amazon.com/eks/)** with **[Grafana Cloud](https://grafana.com/products/cloud/)** integration delivers sub-second OLAP (Online Analytical Processing) queries for data-intensive workloads. Druid excels at ingesting and analyzing high-volume time-series data streams from sources like **[Amazon MSK (Managed Streaming for Apache Kafka)](https://aws.amazon.com/msk/)** or **[Amazon Kinesis](https://aws.amazon.com/kinesis/)**. Our EKS cluster leverages **[Karpenter](https://karpenter.sh/)** for intelligent, cost-optimized node provisioning that automatically scales based on workload demands.

### Flexible Architecture
Build B2B SaaS platforms with complete tenant management, process IoT sensor data at massive scale with real-time dashboards, or create your own application performance monitoring (APM) service. Our modular architecture supports diverse use cases including:
- **Event-driven architectures** using streaming data pipelines
- **Microservices platforms** with service mesh integration
- **Data lake analytics** combining S3, Athena, and Druid
- **Machine learning workflows** with scalable inference endpoints

## Quick Start: CDK Bootstrap & Deployment

Getting started requires AWS credentials, Node.js 18+, and AWS CDK CLI configured locally.

### Prerequisites

```bash
# Install AWS CDK CLI globally
npm install -g aws-cdk

# Verify AWS credentials are configured
aws sts get-caller-identity

# Bootstrap AWS CDK (one-time per account/region)
cdk bootstrap aws://YOUR_ACCOUNT_ID/us-west-2
```

### Deploy Bootstrap Stack

The bootstrap stack creates foundational IAM roles, S3 buckets, and KMS keys required for all Fastish deployments:

```bash
# Clone the bootstrap repository
git clone git@github.com:fast-ish/bootstrap.git
cd bootstrap

# Install dependencies
npm install

# Build TypeScript project
npm run build

# Configure synthesizer name
cat <<EOF > cdk.context.json
{
  "synthesizer": {
    "name": "prod"
  }
}
EOF

# Preview CloudFormation template
npx cdk synth

# Deploy bootstrap stack (creates fastish-prod)
npx cdk deploy
```

**What gets deployed:**
- Main stack: `fastish-prod`
- 8 IAM roles (handshake, lookup, assets, images, deploy, exec, druidExec, webappExec)
- S3 bucket for CDK assets
- ECR repository for container images
- KMS key with alias `alias/fastish`
- SSM parameter for version tracking

**Deployment time:** ~5-10 minutes

For detailed setup instructions, see [Getting Started →](/getting-started/introduction.md)

### What Gets Deployed: CloudFormation Stacks & AWS Resources

Depending on your `releases` configuration, the CDK deployment synthesizes **CloudFormation templates** and provisions:

**Webapp Architecture** (`releases: ["webapp"]`) - **VPC + Cognito + API Gateway + DynamoDB**
- **Amazon VPC** with public/private subnets across 3 Availability Zones
- **Amazon Cognito** user pool with customizable authentication flows
- **API Gateway** with **Lambda** integration and tenant-scoped authorization
- **DynamoDB** tables with global secondary indexes for multi-tenant data
- **Amazon SES** for transactional email delivery
- **AWS Amplify** hosting connected to your Git repository
- **CloudFront** distribution with custom domain support via **Route 53**
- **IAM roles** following least-privilege access patterns

**Druid Architecture** (`releases: ["druid"]`) - **EKS + Kafka + Druid + Grafana**
- **Amazon EKS** cluster (v1.28+) with RBAC configuration
- **Karpenter** for intelligent node provisioning and autoscaling
- **Apache Druid** deployed via **Helm** with optimized resource allocations
- **Amazon RDS PostgreSQL** for Druid metadata storage
- **Amazon S3** buckets for Druid deep storage (long-term data retention)
- **Amazon MSK** (Kafka) cluster for real-time data ingestion
- **AWS Load Balancer Controller** managing ALBs/NLBs for Druid services
- **Grafana Cloud** integration with **OpenTelemetry** collectors
- **Amazon VPC** with dedicated subnets for EKS control plane and data plane nodes

**All Architectures** (`releases: ["all"]`) - **Complete Stack**
- Complete deployment of both webapp and Druid architectures
- Shared **VPC** with peering between webapp and analytics infrastructure
- Unified observability with **CloudWatch** + **Grafana** logging and metrics
- Cross-stack references enabling webapp to query Druid for analytics

For detailed prerequisites and step-by-step setup instructions, see the [Requirements](/getting-started/requirements.md) and [Setup](/getting-started/setup.md) guides.

## Why Choose fastish?

### Boring Technology That Works

We follow the 'Choose Boring Technology' philosophy where it matters most - in your production infrastructure. This means you get the perfect balance of stability and innovation, without unnecessary complexity.

### Security-First Design

Every component begins with a comprehensive security-first heuristic, implementing least-privilege access patterns and detailed audit trails by default. We make the secure way the easy way.

### Community & Support

We're actively seeking feedback and collaboration with teams like yours. Join our growing community where our team is readily available for support, discussions, and brainstorming sessions.

### Built for Production

Our deployment workflows prioritize both speed and safety, with built-in rollback capabilities and extensive validation checks. We make the right thing the easy thing.

## Technology Stack

The foundation rests on carefully selected open source technologies, each chosen for specific operational benefits and proven track records in production environments:

### Infrastructure as Code
- **[AWS CDK](https://aws.amazon.com/cdk/)**: Define cloud infrastructure in Java, TypeScript, Python, or other familiar programming languages. CDK transforms high-level constructs into CloudFormation templates, enabling type-safe infrastructure definitions, IDE autocompletion, and comprehensive testing frameworks. Our implementation uses CDK's L2 (curated) and L3 (patterns) constructs to enforce security guardrails and architectural best practices automatically.

### Container Orchestration & Compute
- **[Amazon EKS](https://aws.amazon.com/eks/)**: Fully managed Kubernetes service that runs upstream Kubernetes, ensuring compatibility with standard K8s tools and extensions. EKS handles control plane operations, patching, and high availability across multiple AWS Availability Zones.
- **[Karpenter](https://karpenter.sh/)**: Open-source Kubernetes cluster autoscaler that provisions right-sized compute resources in seconds, not minutes. Karpenter analyzes pod resource requests and constraints to provision EC2 instances with optimal configurations, supporting diverse workloads from batch processing to real-time analytics. It reduces costs by up to 50% through intelligent bin-packing and automatic adoption of Spot instances where appropriate.
- **[Bottlerocket OS](https://aws.amazon.com/bottlerocket/)**: Purpose-built Linux distribution for running containers with minimal attack surface, automatic security updates, and image-based deployments that enable reliable rollbacks.

### Real-time Analytics & Data Processing
- **[Apache Druid](https://druid.apache.org/)**: Column-oriented distributed data store designed for sub-second OLAP queries at scale. Druid excels at ingesting streaming data from Kafka/Kinesis, automatically indexing it for fast queries, and maintaining real-time + historical data availability. Its architecture includes specialized node types (Coordinator, Broker, Historical, MiddleManager) that enable horizontal scaling and fault tolerance.
- **[Amazon MSK](https://aws.amazon.com/msk/)**: Fully managed Apache Kafka service for building real-time streaming data pipelines. MSK handles broker provisioning, cluster operations, and automatic recovery from common Kafka failures.

### Networking & Traffic Management
- **[AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)**: Kubernetes controller that manages AWS Elastic Load Balancers (ALB/NLB) based on Ingress or Service resources. Provides advanced routing, SSL termination, WAF integration, and automatic scaling of load balancers based on traffic patterns.
- **[Cert-Manager](https://cert-manager.io/)**: Kubernetes add-on that automates SSL/TLS certificate management, including automatic renewal from Let's Encrypt or other ACME-compliant certificate authorities.

### Observability & Monitoring
- **[Grafana Cloud](https://grafana.com/products/cloud/)**: Fully managed observability platform combining metrics (Prometheus), logs (Loki), and traces (Tempo) with pre-built dashboards and alerting capabilities.
- **[OpenTelemetry](https://opentelemetry.io/)**: Vendor-neutral observability framework for collecting metrics, logs, and distributed traces from applications and infrastructure.
- **[Amazon CloudWatch](https://aws.amazon.com/cloudwatch/)**: AWS-native monitoring service for collecting metrics, logs, and events from all AWS services with automated dashboards and alarms.

### Frontend & Application Layer
- **[Next.js](https://nextjs.org/)**: React framework with hybrid static & server rendering, TypeScript support, smart bundling, and route pre-fetching. Deployed on AWS Amplify for automatic CI/CD and global CDN distribution.
- **[Amazon API Gateway](https://aws.amazon.com/api-gateway/)**: Fully managed service for creating, publishing, and securing REST and WebSocket APIs with built-in throttling, authentication, and request/response transformation capabilities.

This technology stack follows the **["Choose Boring Technology"](https://mcfunley.com/choose-boring-technology)** philosophy - each component is battle-tested in production environments, has strong community support, and solves specific problems exceptionally well. By limiting our innovation tokens to architecture and integration patterns rather than technology selection, we deliver reliable, maintainable infrastructure from day one.

## Documentation Guide

### For New Users

Start with the fundamentals to understand how Fastish works:

1. **[Getting Started Overview](getting-started/overview.md)** - Core concepts and architecture
2. **[Security Model](getting-started/security.md)** - API keys, verification, and cross-account access
3. **[Configuration Guide](getting-started/configuration.md)** - User inputs and CloudFormation flow
4. **[Custom Bootstrap](getting-started/bootstrap/custom.md)** - Enhanced security AWS setup

### For Administrators

Learn to manage teams, access control, and deployments:

1. **[Workflow Overview](workflow/overview.md)** - Complete deployment hierarchy
2. **[Synthesizer Setup](workflow/synthesizer.md)** - AWS environment configuration
3. **[Organization Configuration](workflow/organization.md)** - Resource naming and tagging
4. **[Team Management](workflow/teams.md)** - Access control and resource quotas
5. **[Contributor Access](workflow/contributors.md)** - Role-based permissions

### For Developers

Deploy and integrate with infrastructure:

1. **[WebApp Architecture](webapp/overview.md)** - Nested stacks and components
2. **[Release Process](workflow/release.md)** - Complete deployment workflow
3. **Stack Outputs** - Integration examples in [WebApp Overview](webapp/overview.md#using-stack-outputs)

## Key Workflows

### Input → CloudFormation Flow

```
User Inputs → cdk.context.json → Mustache Templates → Java Objects → CloudFormation → AWS Resources
```

**Example:**
- User provides: `organization: "acme-corp"`, `environment: "production"`
- Flows to context: `{"hosted:organization": "acme-corp", "hosted:name": "production"}`
- Creates resources: `acme-corp-production-userpool`, `acme-corp-production-api`

### Deployment Pipeline

```
GitHub Actions Workflow (spaz-infra)
  Trigger: workflow_dispatch or release event

  Determine Environment → Build → Deploy Infrastructure
  (prototype/production)   (Maven)  (CDK Deploy)

Total: 30-50 minutes (varies by architecture)
```

### Workflow Hierarchy

```
Synthesizer (AWS Account + Region)
    └── Organization (acme-corp)
        └── Team (platform-team)
            └── Contributor (alice@acme-corp.com)
                └── Release (webapp-v1-production)
                    └── CloudFormation Stack
                        └── Nested Stacks
```

## Next Steps

- [Get Started with the Introduction →](/getting-started/introduction.md)
- [Review the WebApp Architecture →](/webapp/overview.md)
- [Check the FAQ →](/faq/security.md)
- [Join our Community](https://github.com/fast-ish)

---

*Building the future of infrastructure automation, one deployment at a time.*