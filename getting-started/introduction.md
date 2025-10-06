# Introduction

## Overview

In today's cloud landscape, teams spend more time wrestling with infrastructure complexity than building the features their customers need. According to [Puppet's State of DevOps Report](https://puppet.com/resources/state-of-devops-report), high-performing engineering teams spend 60% more time on new work versus maintenance and firefighting. We've developed a systematic approach to eliminate infrastructure friction - because the most valuable code is the code you never have to write.

Our AWS infrastructure automation service applies this principle alongside established engineering wisdom from the [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/) to dramatically accelerate your path from idea to production. By encoding infrastructure decisions into clear, reusable patterns implemented as [AWS CDK](https://aws.amazon.com/cdk/) constructs, we help teams focus on what matters: delivering product value to their users.

### Architecture Foundations

We build on AWS's proven blueprints to create comprehensive system architectures that scale from prototype to enterprise production workloads. Our approach leverages the concept of **Landing Zones** - pre-configured, secure cloud environments that follow AWS best practices for multi-account structures, identity and access management, governance, data security, network design, and logging.

#### Multi-Tenant Web Application Architecture

Our foundation provides a complete serverless multi-tenant infrastructure layer built on [AWS best practices for SaaS architectures](https://docs.aws.amazon.com/wellarchitected/latest/saas-lens/saas-lens.html). This architecture combines:

- **[Next.js](https://nextjs.org/) on [AWS Amplify](https://aws.amazon.com/amplify/)**: Modern React-based frontend framework with automatic code splitting, server-side rendering (SSR), static site generation (SSG), and incremental static regeneration (ISR). Amplify provides Git-based CI/CD workflows, preview environments for pull requests, and global content delivery through CloudFront.

- **[Amazon API Gateway](https://aws.amazon.com/api-gateway/)**: Fully managed API layer that handles request throttling, authentication via Cognito authorizers, request/response transformation, and automatic API documentation through OpenAPI/Swagger specifications. API Gateway implements tenant isolation through custom authorizers that inject tenant context into every request, ensuring data isolation at the application layer.

- **[Amazon DynamoDB](https://aws.amazon.com/dynamodb/)**: Serverless NoSQL database providing single-digit millisecond performance at any scale. Our schemas implement tenant isolation using composite partition keys (tenant_id#entity_id), enabling efficient querying while maintaining complete data segregation. DynamoDB's global tables support multi-region replication for disaster recovery and reduced latency for globally distributed users.

- **[AWS Lambda](https://aws.amazon.com/lambda/)**: Event-driven compute service that runs code in response to API Gateway requests, DynamoDB streams, S3 events, and scheduled CloudWatch Events. Lambda functions scale automatically from zero to thousands of concurrent executions, with sub-second cold start times using ARM64 (Graviton2) processors.

#### Real-Time Analytics Architecture

For data-intensive workloads requiring sub-second query performance on streaming data, we deploy [Apache Druid](https://druid.apache.org/) on [Amazon EKS](https://aws.amazon.com/eks/) with comprehensive observability through [Grafana Cloud](https://grafana.com/products/cloud/). This architecture enables:

- **Real-time Analytics**: Ingest data from [Amazon MSK (Kafka)](https://aws.amazon.com/msk/), [Amazon Kinesis](https://aws.amazon.com/kinesis/), or batch sources (S3), with data becoming queryable within seconds of ingestion. Druid's columnar storage format and bitmap indexing enable interactive exploration of billion-row datasets.

- **Event Processing**: Build event-driven architectures for IoT telemetry, application performance monitoring (APM), user behavior analytics, fraud detection, and real-time dashboards. Druid's time-partitioned architecture and automatic segment management optimize storage costs while maintaining query performance.

- **Observability Platforms**: Create custom metrics and logging platforms leveraging Druid's native support for time-series rollups, approximate algorithms (HyperLogLog, theta sketches), and complex aggregations across arbitrary dimensions.

These architectures serve as launching points for diverse use cases:
- **B2B SaaS Platforms**: Complete tenant management, usage metering, and billing integration
- **IoT Data Processing**: Ingest sensor data at massive scale with real-time dashboards showing current device status and historical trends
- **Custom APM Services**: Build application performance monitoring solutions with distributed tracing, error tracking, and custom business metrics
- **Data Lake Analytics**: Combine S3 data lakes with Druid for interactive queries on historical data alongside real-time streams

### Getting Started

Getting started is straightforward: with AWS credentials configured and the [AWS CDK CLI](https://docs.aws.amazon.com/cdk/v2/guide/cli.html) installed locally, you're just a `git clone` and `cdk deploy` away from having production-grade infrastructure running in your AWS account.

Our infrastructure is defined using **Java-based CDK constructs** (as seen in the `aws-eks-infra`, `aws-druid-infra`, `aws-webapp-infra`, and `cdk-common` repositories), which provide:

- **Type Safety**: Compile-time validation of infrastructure configurations prevents common deployment errors
- **IDE Support**: Full autocomplete, refactoring, and inline documentation in IntelliJ IDEA, Eclipse, or VS Code
- **Testing Frameworks**: Unit test infrastructure code using JUnit, validate CloudFormation templates with CDK assertions, and perform integration tests against deployed stacks
- **Modular Design**: Shared constructs in `cdk-common` provide reusable patterns (VPC configurations, EKS cluster patterns, database setups) that maintain consistency across deployments

While our infrastructure is implemented in Java, CDK supports extending or customizing it using any CDK-supported language (TypeScript, Python, C#, Go) through CloudFormation exports and cross-stack references.

The deployment creates structured CloudFormation stacks that expose:
- **Stack Outputs**: Public endpoints, resource ARNs, and connection strings available via `aws cloudformation describe-stacks`
- **SSM Parameters**: Sensitive configuration values stored in [AWS Systems Manager Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html) with encryption via AWS KMS
- **Resource Tags**: All resources tagged with deployment metadata (environment, team, cost center) for governance and cost allocation

This structured approach makes it easy to integrate Fastish infrastructure with existing AWS resources, reference outputs in application code, or use the deployment as a foundation for additional custom infrastructure.

### Technology Foundation

The foundation rests on carefully selected open source technologies, each chosen for specific operational benefits and battle-tested in production environments:

#### Infrastructure as Code
**[AWS CDK (Cloud Development Kit)](https://aws.amazon.com/cdk/)** transforms cloud infrastructure management by letting you define resources in familiar programming languages (Java in our case) rather than JSON/YAML templates. CDK provides:

- **L1 (Low-level) Constructs**: Direct CloudFormation resource mappings
- **L2 (Curated) Constructs**: Opinionated defaults with security best practices (e.g., encrypted S3 buckets by default)
- **L3 (Pattern) Constructs**: Multi-resource patterns like "ECS Fargate Service with ALB" or "DynamoDB table with Lambda trigger"

Our implementation leverages L2 and L3 constructs to enforce security guardrails (IAM least privilege, encryption at rest, VPC isolation) and architectural best practices (multi-AZ deployments, automatic backups, monitoring alarms) automatically. Infrastructure code in `cdk-common` uses [Mustache templating](https://mustache.github.io/) to support environment-specific configurations while maintaining DRY (Don't Repeat Yourself) principles.

#### Container Orchestration
**[Karpenter](https://karpenter.sh/)** revolutionizes Kubernetes autoscaling by eliminating the limitations of traditional node groups and [Cluster Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler). While Cluster Autoscaler scales existing node groups based on pending pods, Karpenter:

- Provisions nodes directly from EC2 APIs in ~1 minute vs 5-10 minutes for traditional scaling
- Selects optimal instance types from 600+ EC2 options based on pod requirements (CPU, memory, GPU, architecture)
- Automatically adopts Spot instances when appropriate, reducing costs by up to 90% for fault-tolerant workloads
- Implements bin-packing algorithms to minimize wasted capacity and reduce infrastructure costs by 30-50%
- Supports diverse workload requirements (ARM vs x86, GPU for ML inference, local NVMe for caching) without manual node group management

Running on **[Bottlerocket OS](https://aws.amazon.com/bottlerocket/)** - a minimal, purpose-built Linux distribution for containers - provides additional security and operational benefits: automatic security updates, image-based deployments with atomic rollbacks, and a minimal attack surface with no SSH or package managers.

#### Real-Time OLAP Database
**[Apache Druid](https://druid.apache.org/)** handles real-time analytics with sub-second OLAP (Online Analytical Processing) queries at scale. Druid's architecture includes specialized node types:

- **Coordinator Nodes**: Manage data availability, segment assignments, and replication policies
- **Broker Nodes**: Receive queries from clients, scatter to appropriate data nodes, gather and merge results
- **Historical Nodes**: Serve immutable data segments loaded from deep storage (S3), with local caching for performance
- **MiddleManager Nodes**: Handle real-time data ingestion from Kafka/Kinesis, indexing, and handoff to historical nodes

This separation of concerns enables horizontal scaling of query performance (add brokers/historicals) independently from ingestion throughput (add middle managers). Druid's columnar storage format with bitmap indexes delivers 10-100x faster queries compared to traditional OLAP databases for typical analytical workloads.

#### Traffic Management
The **[AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)** provides granular traffic management by creating AWS Application Load Balancers (ALBs) and Network Load Balancers (NLBs) based on Kubernetes Ingress and Service resources. Features include:

- **Advanced Routing**: Path-based, host-based, and header-based routing rules
- **SSL Termination**: Automatic certificate management via [Cert-Manager](https://cert-manager.io/) and Let's Encrypt
- **WAF Integration**: Attach [AWS WAF](https://aws.amazon.com/waf/) rules for DDoS protection and application-layer security
- **Automatic Scaling**: Load balancers scale automatically based on traffic patterns with no manual intervention
- **Pod-level Routing**: Traffic routes directly to pods (vs traditional NodePort) for improved performance and simplified networking

This combination of managed services (EKS, RDS, MSK, API Gateway), battle-tested open source (Druid, Kubernetes, Kafka), and intelligent automation (Karpenter, CDK) delivers high reliability and cost efficiency without the traditional operational burden of manual configuration, capacity planning, and maintenance.

## Why Choose Us?

Our foundation is built on carefully selected, battle-tested technologies that simply work. While we love exploring cutting-edge solutions, we follow the 'Choose Boring Technology' philosophy where it matters most - in your production infrastructure. This means you get the perfect balance of stability and innovation, without unnecessary complexity.

Security isn't just a feature for us - it's our starting point. Every component we design begins with a comprehensive security-first heuristic, implementing least-privilege access patterns and detailed audit trails by default. We believe in making the secure way the easy way.

What truly sets us apart is our commitment to building relationships, not just providing a service. We're actively seeking feedback and collaboration with teams like yours to shape our platform's evolution. Our community is growing on our socials, where our team is readily available for support, discussions, and brainstorming sessions.

We understand that switching infrastructure providers is a significant decision that requires trust. That's why we're focused on proving our worth through practical examples, detailed documentation, and consistent reliability. We're here for the long haul, ready to grow and adapt alongside your needs.

Our deployment workflows prioritize both speed and safety, with built-in rollback capabilities and extensive validation checks. We believe in making the right thing the easy thing - whether that's following security best practices or implementing reliable deployment patterns.

## Deployment Workflow

Our deployment workflow follows a structured path from initial setup to production launch, implementing **GitOps** principles and **Infrastructure as Code** best practices throughout:

### 1. Synthesizer Configuration

The journey begins with creating a **synthesizer** - a CDK deployment orchestrator that establishes secure communication channels between your AWS account and the Fastish infrastructure repositories. The synthesizer:

- Creates an IAM role with cross-account trust policies following the [principle of least privilege](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html#grant-least-privilege)
- Configures AWS Systems Manager Parameter Store entries for deployment configuration
- Establishes CloudFormation stack dependencies ensuring resources deploy in the correct order
- Sets up CloudWatch Logs groups for capturing deployment events and application logs

The synthesizer configuration is defined in `cdk.context.json` and validated at deployment time using CDK's built-in assertion framework. This validation ensures required fields are present, AWS account IDs are valid, and selected regions support all necessary services.

### 2. Organizational Structure Setup

You'll configure your organization structure through defining:

- **Teams**: Logical groupings of infrastructure and applications (e.g., `platform`, `analytics`, `applications`)
- **Contributors**: IAM principals (users/roles) with appropriate permissions scoped to specific teams
- **Environments**: Isolated deployment targets (development, staging, production) with environment-specific configurations

This structure maps to AWS Organizations best practices, supporting future expansion into multi-account architectures where each environment or team operates in dedicated AWS accounts with centralized billing and governance.

### 3. Release Management

The final stages involve creating and verifying infrastructure **releases** - packaged CloudFormation stacks representing your chosen architectures (webapp, druid, or both). The release process:

1. **Synthesis**: CDK constructs transform into CloudFormation templates with all parameters resolved
2. **Validation**: CloudFormation validates template syntax and resource dependencies
3. **Change Sets**: Preview infrastructure changes before deployment, showing which resources will be created/modified/deleted
4. **Deployment**: CloudFormation executes the change set with automatic rollback on failure
5. **Health Checks**: Post-deployment validation ensures services are responding correctly (EKS cluster accessible, API Gateway endpoints returning 200 OK, databases accepting connections)

Each step is automated through [AWS CodePipeline](https://aws.amazon.com/codepipeline/) and [AWS CodeBuild](https://aws.amazon.com/codebuild/), with built-in security checks (IAM policy validation, security group rule analysis, encryption verification) and automated health monitoring at every stage.

The entire workflow is designed to be intuitive yet powerful, balancing automation with control. Critical operations (production deployments, IAM role modifications) require manual approval gates, while routine tasks (dependency updates, scaling adjustments) execute automatically.

## Support & Resources

Our comprehensive support system is designed to accelerate your team's success with Fastish infrastructure:

### Documentation
Continuously updated with real-world examples, architectural decision records (ADRs), and solutions to common challenges. Our documentation includes:

- **Getting Started Guides**: Step-by-step tutorials with expected outputs and troubleshooting tips
- **Architecture Deep Dives**: Detailed explanations of design decisions, tradeoffs, and scaling characteristics
- **API References**: Complete documentation of CDK constructs, CloudFormation outputs, and SSM parameters
- **Best Practices**: Production-tested patterns for security, performance, cost optimization, and reliability

### Community Resources
- **GitHub Discussions**: [fast-ish GitHub Organization](https://github.com/fast-ish) - Ask questions, share use cases, and collaborate with other users
- **Sample Applications**: Reference implementations demonstrating integration patterns and best practices
- **Blog & Tutorials**: Technical deep-dives on architecture decisions, performance optimizations, and cost management strategies

### External References
Our infrastructure builds on these foundational resources:

- **[AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)**: Five pillars (Operational Excellence, Security, Reliability, Performance Efficiency, Cost Optimization) that guide our design decisions
- **[AWS SaaS Lens](https://docs.aws.amazon.com/wellarchitected/latest/saas-lens/)**: Multi-tenancy patterns and tenant isolation strategies
- **[Kubernetes Documentation](https://kubernetes.io/docs/)**: Essential for understanding EKS cluster operations and workload management
- **[Apache Druid Documentation](https://druid.apache.org/docs/latest/)**: Comprehensive guide to Druid architecture, ingestion, and query optimization
- **[Choose Boring Technology](https://mcfunley.com/choose-boring-technology)**: Dan McKinley's essay on technology selection that informs our stack choices
