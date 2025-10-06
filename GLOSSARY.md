# Glossary

Terminology reference for the Fastish infrastructure platform. Terms are organized alphabetically within categories.

---

## Platform Components

| Term | Definition |
|------|------------|
| **aws-druid-infra** | Open source CDK application that provisions Apache Druid analytics clusters on Amazon EKS with integrated RDS, S3, and MSK services. |
| **aws-eks-infra** | Open source CDK application that provisions production-ready Amazon EKS clusters with managed add-ons, Karpenter autoscaling, and Grafana Cloud observability. |
| **aws-webapp-infra** | Open source CDK application that provisions serverless web application infrastructure including VPC, Cognito, DynamoDB, SES, and API Gateway. |
| **cdk-common** | Shared library of AWS CDK constructs used by all Fastish infrastructure projects. Implements Mustache templating and Jackson YAML processing. |
| **Fastish** | Infrastructure-as-a-service platform that delivers production-ready AWS infrastructure through codified patterns and automated deployment pipelines. |
| **Network Service** | Internal platform service providing shared VPC infrastructure and cross-stack connectivity via Transit Gateway and VPC peering. |
| **Orchestrator** | Internal platform service that automates release pipelines using AWS CodePipeline V2 and CodeBuild for CDK synthesis and deployment. |
| **Portal** | Internal platform service providing multi-tenant subscriber management, authentication via Cognito, and deployment request handling. |
| **Reporting Service** | Internal platform service that tracks usage metering and cost attribution using BCM Data Export and Amazon Athena. |

---

## AWS Services

| Term | Definition | Reference |
|------|------------|-----------|
| **Amazon Cognito** | Managed identity service providing user pools for authentication and identity pools for AWS credential federation. | [Documentation](https://docs.aws.amazon.com/cognito/latest/developerguide/what-is-amazon-cognito.html) |
| **Amazon DynamoDB** | Fully managed NoSQL database service with single-digit millisecond latency at any scale. | [Documentation](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Introduction.html) |
| **Amazon EKS** | Elastic Kubernetes Service - managed Kubernetes control plane that runs across multiple AWS Availability Zones. | [Documentation](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html) |
| **Amazon MSK** | Managed Streaming for Apache Kafka - fully managed service for building and running Apache Kafka applications. | [Documentation](https://docs.aws.amazon.com/msk/latest/developerguide/what-is-msk.html) |
| **Amazon RDS** | Relational Database Service - managed database service supporting PostgreSQL, MySQL, and other engines. | [Documentation](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Welcome.html) |
| **Amazon S3** | Simple Storage Service - object storage with industry-leading scalability, availability, and durability. | [Documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html) |
| **Amazon SES** | Simple Email Service - cloud-based email sending service for transactional and marketing emails. | [Documentation](https://docs.aws.amazon.com/ses/latest/dg/Welcome.html) |
| **Amazon VPC** | Virtual Private Cloud - logically isolated section of AWS where you launch resources in a defined virtual network. | [Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html) |
| **API Gateway** | Fully managed service for creating, publishing, and managing REST, HTTP, and WebSocket APIs. | [Documentation](https://docs.aws.amazon.com/apigateway/latest/developerguide/welcome.html) |
| **AWS CDK** | Cloud Development Kit - framework for defining cloud infrastructure in code using familiar programming languages. | [Documentation](https://docs.aws.amazon.com/cdk/v2/guide/home.html) |
| **AWS CloudFormation** | Infrastructure as code service that provisions AWS resources using declarative templates. | [Documentation](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/Welcome.html) |
| **AWS CodeBuild** | Fully managed continuous integration service that compiles source code, runs tests, and produces artifacts. | [Documentation](https://docs.aws.amazon.com/codebuild/latest/userguide/welcome.html) |
| **AWS CodePipeline** | Continuous delivery service for automating release pipelines for application and infrastructure updates. | [Documentation](https://docs.aws.amazon.com/codepipeline/latest/userguide/welcome.html) |
| **AWS Lambda** | Serverless compute service that runs code in response to events without provisioning servers. | [Documentation](https://docs.aws.amazon.com/lambda/latest/dg/welcome.html) |
| **CloudWatch** | Monitoring and observability service for AWS resources and applications. | [Documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/WhatIsCloudWatch.html) |

---

## Kubernetes & Container Terms

| Term | Definition | Reference |
|------|------------|-----------|
| **Bottlerocket** | Linux-based operating system purpose-built by AWS for hosting containers with minimal attack surface. | [Documentation](https://aws.amazon.com/bottlerocket/) |
| **cert-manager** | Kubernetes add-on that automates management and issuance of TLS certificates. | [Documentation](https://cert-manager.io/docs/) |
| **CoreDNS** | DNS server that serves as Kubernetes cluster DNS, enabling service discovery. | [Documentation](https://coredns.io/) |
| **Helm** | Package manager for Kubernetes that helps define, install, and upgrade applications. | [Documentation](https://helm.sh/docs/) |
| **Karpenter** | Kubernetes node autoscaler that provisions right-sized compute resources in response to pending pods. | [Documentation](https://karpenter.sh/docs/) |
| **kubectl** | Command-line tool for communicating with Kubernetes cluster control planes. | [Documentation](https://kubernetes.io/docs/reference/kubectl/) |
| **Managed Node Group** | EKS feature that automates provisioning and lifecycle management of worker nodes. | [Documentation](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html) |
| **Pod Identity** | EKS feature that enables pods to assume IAM roles without managing credentials. | [Documentation](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html) |
| **VPC CNI** | Amazon VPC Container Network Interface plugin that provides native VPC networking for Kubernetes pods. | [Documentation](https://docs.aws.amazon.com/eks/latest/userguide/managing-vpc-cni.html) |

---

## Apache Druid Terms

| Term | Definition | Reference |
|------|------------|-----------|
| **Broker** | Druid process that handles queries from external clients and routes them to Historical nodes. | [Documentation](https://druid.apache.org/docs/latest/design/broker.html) |
| **Coordinator** | Druid process that manages data availability and segment distribution across Historical nodes. | [Documentation](https://druid.apache.org/docs/latest/design/coordinator.html) |
| **Deep Storage** | Permanent backup storage for Druid segments, typically S3 in AWS deployments. | [Documentation](https://druid.apache.org/docs/latest/dependencies/deep-storage.html) |
| **Historical** | Druid process that stores and serves immutable data segments for queries. | [Documentation](https://druid.apache.org/docs/latest/design/historical.html) |
| **MiddleManager** | Druid process that executes submitted ingestion tasks and creates new data segments. | [Documentation](https://druid.apache.org/docs/latest/design/middlemanager.html) |
| **Overlord** | Druid process that controls data ingestion workload assignment and task scheduling. | [Documentation](https://druid.apache.org/docs/latest/design/overlord.html) |
| **Router** | Druid process that routes requests to Brokers, Coordinators, and Overlords; hosts web console. | [Documentation](https://druid.apache.org/docs/latest/design/router.html) |
| **Segment** | Druid's fundamental storage unit containing time-partitioned, immutable data. | [Documentation](https://druid.apache.org/docs/latest/design/segments.html) |

---

## Infrastructure as Code Terms

| Term | Definition | Reference |
|------|------------|-----------|
| **CDK Bootstrap** | One-time setup process that provisions resources (S3 bucket, IAM roles) required for CDK deployments. | [Documentation](https://docs.aws.amazon.com/cdk/v2/guide/bootstrapping.html) |
| **CDK Context** | Key-value pairs that provide configuration values to CDK applications, stored in `cdk.context.json`. | [Documentation](https://docs.aws.amazon.com/cdk/v2/guide/context.html) |
| **CDK Construct** | Cloud component encapsulating AWS resources, available at three levels (L1, L2, L3) of abstraction. | [Documentation](https://docs.aws.amazon.com/cdk/v2/guide/constructs.html) |
| **CDK Synth** | CDK synthesis process that generates CloudFormation templates from CDK application code. | [Documentation](https://docs.aws.amazon.com/cdk/v2/guide/ref-cli-cmd-synth.html) |
| **CloudFormation Stack** | Collection of AWS resources managed as a single unit, created from a CloudFormation template. | [Documentation](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacks.html) |
| **Jackson** | Java library for JSON and YAML processing, used for configuration deserialization. | [Documentation](https://github.com/FasterXML/jackson) |
| **Mustache** | Logic-less templating language used for configuration file variable substitution. | [Documentation](https://mustache.github.io/) |
| **Nested Stack** | CloudFormation stack created as part of another stack, enabling modular infrastructure. | [Documentation](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-cfn-nested-stacks.html) |

---

## DevOps & Metrics Terms

| Term | Definition | Reference |
|------|------------|-----------|
| **Change Failure Rate** | DORA metric measuring percentage of deployments causing production failures or requiring remediation. | [DORA](https://dora.dev/guides/dora-metrics-four-keys/) |
| **Deployment Frequency** | DORA metric measuring how often code is deployed to production. | [DORA](https://dora.dev/guides/dora-metrics-four-keys/) |
| **DORA Metrics** | DevOps Research and Assessment metrics: Deployment Frequency, Lead Time, Change Failure Rate, MTTR. | [DORA](https://dora.dev/) |
| **Lead Time for Changes** | DORA metric measuring time from code commit to production deployment. | [DORA](https://dora.dev/guides/dora-metrics-four-keys/) |
| **MTTR** | Mean Time to Recovery - DORA metric measuring time to restore service after an incident. | [DORA](https://dora.dev/guides/dora-metrics-four-keys/) |

---

## Observability Terms

| Term | Definition | Reference |
|------|------------|-----------|
| **Grafana Cloud** | Managed observability platform providing metrics (Mimir), logs (Loki), traces (Tempo), and profiling (Pyroscope). | [Documentation](https://grafana.com/docs/grafana-cloud/) |
| **Loki** | Log aggregation system designed for efficiency and ease of operation, part of Grafana stack. | [Documentation](https://grafana.com/oss/loki/) |
| **Mimir** | Horizontally scalable, highly available Prometheus-compatible metrics backend. | [Documentation](https://grafana.com/oss/mimir/) |
| **OpenTelemetry** | Vendor-neutral framework for collecting telemetry data (metrics, logs, traces). | [Documentation](https://opentelemetry.io/docs/) |
| **Pyroscope** | Continuous profiling platform for analyzing application performance. | [Documentation](https://grafana.com/oss/pyroscope/) |
| **Tempo** | High-scale distributed tracing backend, part of Grafana stack. | [Documentation](https://grafana.com/oss/tempo/) |

---

## Security Terms

| Term | Definition | Reference |
|------|------------|-----------|
| **DKIM** | DomainKeys Identified Mail - email authentication method using cryptographic signatures. | [Documentation](https://docs.aws.amazon.com/ses/latest/dg/send-email-authentication-dkim.html) |
| **IAM Role** | AWS identity with permission policies determining what actions the identity can perform. | [Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html) |
| **KMS** | Key Management Service - AWS service for creating and managing cryptographic keys. | [Documentation](https://docs.aws.amazon.com/kms/latest/developerguide/overview.html) |
| **Least Privilege** | Security principle of granting only the minimum permissions necessary to perform a task. | [Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html#grant-least-privilege) |
| **NACL** | Network Access Control List - stateless firewall for controlling subnet traffic in VPC. | [Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html) |
| **OIDC** | OpenID Connect - identity layer on OAuth 2.0 protocol for authentication. | [Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html) |
| **Security Group** | Virtual firewall controlling inbound and outbound traffic for AWS resources. | [Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html) |

---

## Acronyms

| Acronym | Expansion |
|---------|-----------|
| **ALB** | Application Load Balancer |
| **AMI** | Amazon Machine Image |
| **API** | Application Programming Interface |
| **ARN** | Amazon Resource Name |
| **AZ** | Availability Zone |
| **BCM** | Billing and Cost Management |
| **CDK** | Cloud Development Kit |
| **CI/CD** | Continuous Integration / Continuous Delivery |
| **CIDR** | Classless Inter-Domain Routing |
| **CLI** | Command Line Interface |
| **CNI** | Container Network Interface |
| **CORS** | Cross-Origin Resource Sharing |
| **CQRS** | Command Query Responsibility Segregation |
| **CSI** | Container Storage Interface |
| **DNS** | Domain Name System |
| **EC2** | Elastic Compute Cloud |
| **ECR** | Elastic Container Registry |
| **EFS** | Elastic File System |
| **EKS** | Elastic Kubernetes Service |
| **GSI** | Global Secondary Index |
| **HA** | High Availability |
| **HTTP** | Hypertext Transfer Protocol |
| **IAM** | Identity and Access Management |
| **IaC** | Infrastructure as Code |
| **JWT** | JSON Web Token |
| **LTS** | Long Term Support |
| **MFA** | Multi-Factor Authentication |
| **MSK** | Managed Streaming for Apache Kafka |
| **MSQ** | Multi-Stage Query (Druid) |
| **MTTR** | Mean Time to Recovery |
| **NAT** | Network Address Translation |
| **NLB** | Network Load Balancer |
| **OLAP** | Online Analytical Processing |
| **POJO** | Plain Old Java Object |
| **RBAC** | Role-Based Access Control |
| **RDS** | Relational Database Service |
| **REST** | Representational State Transfer |
| **RPO** | Recovery Point Objective |
| **RTO** | Recovery Time Objective |
| **S3** | Simple Storage Service |
| **SAML** | Security Assertion Markup Language |
| **SDK** | Software Development Kit |
| **SES** | Simple Email Service |
| **SNS** | Simple Notification Service |
| **SQS** | Simple Queue Service |
| **SSO** | Single Sign-On |
| **TLS** | Transport Layer Security |
| **VPC** | Virtual Private Cloud |
| **YAML** | YAML Ain't Markup Language |

---

## Related Documentation

Terms in this glossary are referenced throughout the platform documentation:

| Document | Key Terms Used |
|----------|----------------|
| [Troubleshooting Guide](docs/TROUBLESHOOTING.md) | CDK, CloudFormation, EKS, Druid components |
| [Upgrade Guide](docs/UPGRADE.md) | Semantic versioning, CloudFormation stacks |
| [IAM Permissions](docs/IAM-PERMISSIONS.md) | IAM roles, policies, least privilege |
| [Network Requirements](docs/NETWORK-REQUIREMENTS.md) | VPC, CIDR, NAT Gateway, security groups |
| [Capacity Planning](docs/CAPACITY-PLANNING.md) | Instance types, DynamoDB capacity, Karpenter |
| [Validation Guide](docs/VALIDATION.md) | Health checks, stack status, pod states |

---

**Last Updated**: 2024-01 (Initial Release)
