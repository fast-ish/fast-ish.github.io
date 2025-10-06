# Requirements

## Prerequisites

Before getting started with Fastish, ensure you have the following requirements in place. These prerequisites enable smooth deployment and operation of your infrastructure.

### AWS Account Setup

**Active AWS Account**
- You'll need an active AWS account with administrative access or specific IAM permissions (detailed below)
- If you're new to AWS, sign up at [aws.amazon.com](https://aws.amazon.com/)
- Consider using [AWS Organizations](https://aws.amazon.com/organizations/) if deploying across multiple environments (dev, staging, prod) for centralized billing and governance

**IAM Permissions Required**

The IAM user or role deploying Fastish infrastructure needs permissions to create and manage:

```json
{
  "Required AWS Services": [
    "CloudFormation - Create/update/delete stacks",
    "IAM - Create roles, policies, and instance profiles",
    "VPC - Create VPCs, subnets, route tables, NAT gateways",
    "EC2 - Launch instances, manage security groups, EBS volumes",
    "EKS - Create clusters, node groups, and addon configurations",
    "RDS - Create PostgreSQL instances (for Druid metadata)",
    "S3 - Create buckets, configure lifecycle policies",
    "DynamoDB - Create tables, indexes, and configure autoscaling",
    "API Gateway - Create REST APIs, custom domains, authorizers",
    "Lambda - Create functions, layers, and event source mappings",
    "Cognito - Create user pools and identity pools",
    "Route53 - Create hosted zones and DNS records",
    "MSK - Create Kafka clusters (for Druid ingestion)",
    "Systems Manager - Create/read Parameter Store parameters",
    "Secrets Manager - Create and rotate secrets",
    "KMS - Create and manage encryption keys",
    "CloudWatch - Create log groups, metrics, and alarms",
    "SES - Configure email sending and receipt rules"
  ]
}
```

For production deployments, we recommend using the **AdministratorAccess** managed policy during initial setup, then creating a least-privilege custom policy after understanding your specific requirements. See [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html) for guidance.

**AWS Credentials Configuration**

Configure credentials locally using one of these methods:

```bash
# Method 1: AWS CLI configuration (recommended for development)
aws configure
# Enter: AWS Access Key ID, Secret Access Key, Default region, Output format

# Method 2: Environment variables (useful for CI/CD)
export AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="YOUR_SECRET_KEY"
export AWS_DEFAULT_REGION="us-west-2"

# Method 3: AWS SSO (recommended for organizations)
aws configure sso
# Follow prompts to authenticate via browser

# Verify credentials
aws sts get-caller-identity
```

For security, consider using [AWS IAM Identity Center (AWS SSO)](https://aws.amazon.com/iam/identity-center/) with temporary credentials rather than long-lived access keys.

### Development Environment

**Java Development Kit (JDK)**

Since Fastish infrastructure is written in Java (as seen in `aws-eks-infra`, `aws-druid-infra`, `aws-webapp-infra`), you'll need:

- **Java**: Version 21 or higher ([Amazon Corretto 21](https://aws.amazon.com/corretto/) recommended)
- **Maven**: Version 3.8 or higher for building Java projects

```bash
# Install Amazon Corretto 21 (macOS with Homebrew)
brew install corretto21

# Install Maven
brew install maven

# Verify installations
java --version    # Should show 21.x.x
mvn --version     # Should show 3.8.x or higher
```

For other platforms, download from:
- Java: [Amazon Corretto Downloads](https://aws.amazon.com/corretto/)
- Maven: [Apache Maven Downloads](https://maven.apache.org/download.cgi)

**Node.js & npm** (for CDK CLI and bootstrap repository)

- **Node.js**: Version 18 or higher (LTS version recommended)
- **npm**: Version 8 or higher (included with Node.js)

```bash
# Install Node.js (macOS with Homebrew)
brew install node@20

# Or use nvm (Node Version Manager) for managing multiple versions
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 20
nvm use 20

# Verify installations
node --version    # Should show v20.x.x
npm --version     # Should show 8.x.x or higher
```

**AWS CDK CLI**

```bash
# Install AWS CDK globally
npm install -g aws-cdk

# Verify installation
cdk --version    # Should show 2.x.x

# Bootstrap your AWS account (one-time setup per region)
# This creates the necessary S3 buckets and IAM roles for CDK deployments
cdk bootstrap aws://YOUR_ACCOUNT_ID/us-west-2
```

Learn more about CDK bootstrapping in the [AWS CDK Bootstrap Documentation](https://docs.aws.amazon.com/cdk/v2/guide/bootstrapping.html).

**Git Version Control**

```bash
# Verify Git is installed
git --version    # Should show 2.x.x or higher

# Configure Git (if not already done)
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Generate SSH key for GitHub access
ssh-keygen -t ed25519 -C "your.email@example.com"
# Add the public key to your GitHub account
```

### Recommended Knowledge & Skills

To effectively work with Fastish infrastructure, familiarity with the following concepts will accelerate your success:

**Cloud Infrastructure (Essential)**
- [AWS Core Services](https://aws.amazon.com/getting-started/): VPC, EC2, S3, IAM, CloudFormation
- [Infrastructure as Code (IaC)](https://docs.aws.amazon.com/whitepapers/latest/introduction-devops-aws/infrastructure-as-code.html) concepts and benefits
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/) fundamentals

**Container & Kubernetes (for Druid architecture)**
- [Docker](https://docs.docker.com/) basics: images, containers, registries
- [Kubernetes](https://kubernetes.io/docs/concepts/) fundamentals: Pods, Deployments, Services, Ingress
- [kubectl](https://kubernetes.io/docs/reference/kubectl/) command-line tool usage
- [Helm](https://helm.sh/docs/) for managing Kubernetes applications

**Serverless & API Development (for Webapp architecture)**
- [AWS Lambda](https://docs.aws.amazon.com/lambda/) function development and event-driven patterns
- [API Gateway](https://docs.aws.amazon.com/apigateway/) REST API design and authorization
- [DynamoDB](https://docs.aws.amazon.com/dynamodb/) data modeling for NoSQL workloads
- [Next.js](https://nextjs.org/docs) React framework and server-side rendering concepts

**Programming (Helpful)**
- **Java**: For customizing CDK infrastructure constructs
- **TypeScript/JavaScript**: For extending the bootstrap repository or building web applications
- **Command Line**: Bash/Shell scripting for automation and deployment workflows

**Optional but Valuable**
- [Apache Druid](https://druid.apache.org/docs/latest/) architecture for real-time analytics
- [Apache Kafka](https://kafka.apache.org/documentation/) for streaming data pipelines
- [CI/CD Pipelines](https://aws.amazon.com/devops/continuous-delivery/) with AWS CodePipeline/GitHub Actions

## Service Quotas

AWS accounts have default service quotas (formerly called limits) that may need adjustment for large-scale deployments. Before deploying Fastish infrastructure, verify your account has sufficient quotas for the services you plan to use.

### Critical Quotas to Check

**For All Deployments**

```bash
# View your current service quotas
aws service-quotas list-service-quotas --service-code cloudformation
aws service-quotas list-service-quotas --service-code vpc
aws service-quotas list-service-quotas --service-code ec2
```

| Service | Quota Name | Recommended Minimum | Default | Why It Matters |
|---------|-----------|---------------------|---------|----------------|
| **VPC** | VPCs per Region | 10 | 5 | Each architecture may create 1-2 VPCs (webapp + Druid) |
| **VPC** | NAT Gateways per AZ | 5 | 5 | Each VPC creates NAT gateways for outbound internet access |
| **VPC** | Internet Gateways per Region | 5 | 5 | One per VPC for public subnet connectivity |
| **EC2** | Running On-Demand Instances | 50+ | 20 | EKS nodes, NAT instances, bastion hosts |
| **CloudFormation** | Stacks per Region | 200 | 200 | Each CDK stack creates one CloudFormation stack |
| **IAM** | Roles per Account | 500 | 1000 | Service roles for Lambda, EKS, EC2, RDS |

**For Webapp Architecture**

| Service | Quota Name | Recommended Minimum | Default | Notes |
|---------|-----------|---------------------|---------|-------|
| **API Gateway** | Regional APIs per Account | 20 | 600 | One per environment (dev, staging, prod) |
| **DynamoDB** | Tables per Region | 256 | 2500 | Varies by data model complexity |
| **Lambda** | Concurrent Executions | 1000+ | 1000 | Peak traffic handling capacity |
| **Cognito** | User Pools per Account | 10 | 1000 | One per environment typically |
| **Route53** | Hosted Zones per Account | 500 | 500 | Custom domains for frontend/API |
| **SES** | Sending Quota | Varies | 200 emails/day (sandbox) | Request production access for transactional emails |

**For Druid Architecture**

| Service | Quota Name | Recommended Minimum | Default | Notes |
|---------|-----------|---------------------|---------|-------|
| **EKS** | Clusters per Region | 5 | 100 | One cluster per environment |
| **EC2** | Running Spot Instances | 100+ | 20 | Karpenter uses Spot for cost savings |
| **EC2** | Instance Types | m5.*, r5.*, c5.* | Varies | Ensure quota for planned instance families |
| **RDS** | DB Instances | 10 | 40 | PostgreSQL for Druid metadata |
| **MSK** | Kafka Clusters per Region | 3 | 25 | Real-time data ingestion |
| **EBS** | Storage (GP3) in TiB | 50+ | 50 | Druid segment storage, database volumes |
| **VPC** | Security Groups per VPC | 100 | 2500 | EKS, RDS, MSK isolation |

### Requesting Quota Increases

If your current quotas are insufficient:

**Via AWS Console**
1. Navigate to [Service Quotas Console](https://console.aws.amazon.com/servicequotas/)
2. Select the service (e.g., "Amazon Elastic Compute Cloud (Amazon EC2)")
3. Find the specific quota (e.g., "Running On-Demand Standard instances")
4. Click "Request quota increase"
5. Enter new value and business justification
6. Submit request (typically approved within 24-48 hours)

**Via AWS CLI**
```bash
# Request increase for EC2 On-Demand instances
aws service-quotas request-service-quota-increase \
  --service-code ec2 \
  --quota-code L-1216C47A \
  --desired-value 100 \
  --region us-west-2

# Check request status
aws service-quotas list-requested-service-quota-change-history-by-quota \
  --service-code ec2 \
  --quota-code L-1216C47A \
  --region us-west-2
```

Learn more in the [AWS Service Quotas User Guide](https://docs.aws.amazon.com/servicequotas/latest/userguide/intro.html).

### Special Considerations

**Amazon SES Sandbox**
New AWS accounts start in the SES sandbox with restrictions:
- Can only send to verified email addresses
- Limited to 200 messages per 24 hours
- Maximum send rate of 1 message per second

For production deployments, [request production access](https://docs.aws.amazon.com/ses/latest/dg/request-production-access.html) which typically requires:
- Valid business use case description
- Process for handling bounces and complaints
- Compliance with AWS Acceptable Use Policy

**EKS Kubernetes Version Support**
EKS supports the latest four Kubernetes minor versions. Our infrastructure defaults to Kubernetes 1.28 but can be configured for newer versions. Check [EKS Kubernetes versions](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html) for current support matrix.

## Supported Regions

Fastish infrastructure supports deployment to the following AWS regions. Regional selection should consider data sovereignty requirements, latency to end users, and availability of required services.

### Commercial Regions

| Region Code | Region Name | Notes |
|-------------|-------------|-------|
| `us-west-1` | US West (N. California) | 2 Availability Zones |
| `us-west-2` | US West (Oregon) | 4 Availability Zones (recommended for production) |
| `us-east-1` | US East (N. Virginia) | 6 Availability Zones, largest region |
| `us-east-2` | US East (Ohio) | 3 Availability Zones |

### AWS GovCloud Regions (ITAR/FedRAMP)

| Region Code | Region Name | Requirements |
|-------------|-------------|--------------|
| `us-gov-east-1` | AWS GovCloud (US-East) | Requires AWS GovCloud account |
| `us-gov-west-1` | AWS GovCloud (US-West) | Requires AWS GovCloud account |

**Note:** AWS GovCloud regions require a separate account signup process and are designed for US government agencies and contractors handling sensitive controlled unclassified information (CUI). See [AWS GovCloud Documentation](https://aws.amazon.com/govcloud-us/) for details.

### Service Availability by Region

Not all AWS services are available in every region. Verify service availability before deployment:

```bash
# Check if a service is available in your target region
aws ssm get-parameters-by-path \
  --path /aws/service/global-infrastructure/services/eks/regions \
  --query 'Parameters[].Value' \
  --output text

# List all services available in a specific region
aws ssm get-parameters-by-path \
  --path /aws/service/global-infrastructure/regions/us-west-2/services \
  --query 'Parameters[].Value' \
  --output text
```

Check the [AWS Regional Services List](https://aws.amazon.com/about-aws/global-infrastructure/regional-product-services/) for comprehensive service availability.

### Multi-Region Considerations

For multi-region deployments (future roadmap feature):
- **Data Residency**: Some regulations require data to remain within specific geographic boundaries (GDPR, data localization laws)
- **Latency**: Deploy infrastructure close to your users (US users → us-west-2, European users → eu-west-1)
- **Disaster Recovery**: Deploy to multiple regions for business continuity (RTO/RPO requirements)
- **Cost**: Data transfer between regions incurs charges ($0.02/GB typically)

## Estimated Costs

Understanding the cost implications of Fastish infrastructure helps with budget planning and architectural decisions.

### Webapp Architecture (Monthly Estimates)

**Development/Staging Environment:**
- API Gateway: ~$10-30 (based on requests)
- Lambda: ~$5-20 (based on invocations and duration)
- DynamoDB: ~$5-25 (on-demand pricing for variable workloads)
- Cognito: Free tier (up to 50,000 MAUs)
- Amplify: ~$15-50 (build minutes + hosting)
- Route53: $0.50 per hosted zone
- CloudWatch: ~$10-20 (logs and metrics)
- **Total: ~$50-150/month**

**Production Environment (Low-Medium Traffic):**
- API Gateway: ~$100-300
- Lambda: ~$50-200
- DynamoDB: ~$50-500 (consider provisioned capacity for predictable workloads)
- Cognito: ~$275 (50,000-100,000 MAUs)
- Amplify: ~$100-300
- CloudFront: ~$50-200
- **Total: ~$625-2000/month**

### Druid Architecture (Monthly Estimates)

**Development Environment:**
- EKS Cluster: $73 (control plane)
- EC2 (On-Demand m5.large): ~$140 (2 nodes)
- EBS: ~$20 (200 GB gp3)
- RDS PostgreSQL (db.t3.medium): ~$60
- MSK (2 brokers, kafka.t3.small): ~$72
- ALB: ~$20
- **Total: ~$385/month**

**Production Environment:**
- EKS Cluster: $73 (control plane)
- EC2 (Spot m5.2xlarge): ~$800-1200 (Karpenter-managed, 5-10 nodes)
- EBS: ~$200 (2 TB gp3 across nodes)
- RDS PostgreSQL (db.r5.2xlarge Multi-AZ): ~$800
- MSK (3 brokers, kafka.m5.large): ~$450
- ALB: ~$40
- S3 Deep Storage: ~$50-200 (depends on retention)
- Data Transfer: ~$100-500
- **Total: ~$2500-4000/month**

**Cost Optimization Tips:**
- Use Savings Plans or Reserved Instances for predictable workloads (up to 72% savings)
- Enable Karpenter with Spot instances for non-critical workloads (up to 90% savings on compute)
- Implement S3 Intelligent-Tiering for deep storage (automatic cost optimization)
- Configure DynamoDB on-demand mode for variable traffic, provisioned for steady state
- Use CloudWatch Logs retention policies to avoid indefinite log storage costs

Estimate costs for your specific usage with the [AWS Pricing Calculator](https://calculator.aws/).

## Next Steps

Once you've verified all requirements are met and understand the cost implications:

1. **[Set up your environment →](/getting-started/setup.md)** - Clone repositories and configure CDK
2. **[Bootstrap your AWS account →](/getting-started/bootstrap/cdk.md)** - Prepare AWS account for CDK deployments
3. **[Launch your infrastructure →](/getting-started/launch.md)** - Deploy your chosen architecture

If you have questions about requirements or need assistance with quota increases, refer to the [Support & Resources](/support.md) section.