# Quick Start (10 Minutes)

Get Fastish infrastructure deployed to your AWS account in under 10 minutes.

## Prerequisites

Before starting, ensure you have:

- **AWS Account** with administrator access
- **AWS CLI** configured with valid credentials
- **Node.js 18+** installed ([download](https://nodejs.org/))
- **Git** installed

**Verify prerequisites:**
```bash
# Check Node.js version
node --version  # Should be 18.x or higher

# Check AWS credentials
aws sts get-caller-identity

# Expected output shows your account ID
# {
#   "UserId": "AIDAI...",
#   "Account": "123456789012",
#   "Arn": "arn:aws:iam::123456789012:user/yourname"
# }
```

## Step 1: Install AWS CDK CLI

```bash
# Install AWS CDK globally
npm install -g aws-cdk

# Verify installation
cdk --version
```

## Step 2: Bootstrap AWS CDK

This creates the foundational resources AWS CDK needs (S3 bucket, IAM roles).

**One-time setup per AWS account/region:**

```bash
# Replace with your AWS account ID
cdk bootstrap aws://123456789012/us-west-2
```

**What this creates:**
- S3 bucket: `cdk-*-assets-123456789012-us-west-2`
- ECR repository: `cdk-*-container-assets-123456789012-us-west-2`
- IAM roles: `cdk-*-deploy-role-123456789012-us-west-2`
- SSM parameter: `/cdk-bootstrap/*/version`

**Time:** ~2 minutes

## Step 3: Deploy Fastish Bootstrap Stack

The Fastish bootstrap stack creates additional IAM roles and resources for deploying Fastish applications.

```bash
# Clone bootstrap repository
git clone git@github.com:fast-ish/bootstrap.git
cd bootstrap

# Install dependencies
npm install

# Build TypeScript project
npm run build

# Create configuration file
cat <<EOF > cdk.context.json
{
  "synthesizer": {
    "name": "prod"
  }
}
EOF

# Deploy bootstrap stack
npx cdk deploy
```

**What gets deployed:**
- Stack name: `fastish-prod`
- 8 IAM roles (handshake, lookup, assets, images, deploy, exec, druidExec, webappExec)
- S3 bucket for Fastish deployment assets
- ECR repository for container images
- KMS key (alias: `alias/fastish`)
- SSM parameter for version tracking

**Time:** ~5 minutes

**Confirm deployment:**
```bash
# List CloudFormation stacks
aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE

# Should show:
# - CDKToolkit
# - fastish-prod
# - fastish-prod-FastishRoles (nested)
# - fastish-prod-FastishStorage (nested)
```

## Step 4: Save Bootstrap Outputs

After deployment completes, capture the stack outputs:

```bash
# Get bootstrap stack outputs
aws cloudformation describe-stacks \
  --stack-name fastish-prod \
  --query 'Stacks[0].Outputs' \
  --output json > fastish-bootstrap-outputs.json
```

**These outputs contain:**
- IAM role ARNs
- S3 bucket ARN
- ECR repository ARN
- KMS key ARN

Save this file - you'll reference these values when deploying applications.

## What's Next?

You've successfully deployed the Fastish bootstrap stack. Now you can deploy applications:

### Option A: Deploy Apache Druid Analytics Platform

```bash
git clone git@github.com:fast-ish/aws-druid-infra.git
cd aws-druid-infra

# Copy template and edit with your values
cp cdk.context.template.json cdk.context.json
nano cdk.context.json  # Edit configuration

# Deploy
mvn clean install
cdk deploy
```

**See:** [Druid Architecture Overview →](/druid/overview.md)

### Option B: Deploy Multi-Tenant SaaS WebApp

```bash
git clone git@github.com:fast-ish/aws-webapp-infra.git
cd aws-webapp-infra/infra

# Copy template and edit with your values
cp cdk.context.template.json cdk.context.json
nano cdk.context.json  # Edit configuration

# Deploy
mvn clean install
cdk deploy
```

**See:** [WebApp Architecture Overview →](/webapp/overview.md)

## Troubleshooting

### Error: "Unable to resolve AWS account to use"

**Cause:** AWS credentials not configured

**Fix:**
```bash
aws configure
# Enter: Access Key ID, Secret Access Key, Region, Output format
```

### Error: "Stack [fastish-prod] already exists"

**Cause:** Bootstrap stack already deployed

**Fix:** This is expected if you've deployed before. To update:
```bash
npx cdk deploy  # Updates existing stack
```

### Error: "User is not authorized to perform: iam:CreateRole"

**Cause:** AWS credentials lack permissions

**Fix:** Ensure your IAM user/role has AdministratorAccess or equivalent permissions for:
- IAM (create roles, policies)
- CloudFormation (create stacks)
- S3 (create buckets)
- KMS (create keys)
- SSM (create parameters)

### Bootstrap stack deployment stuck

**Cause:** CloudFormation waiting for manual approval or encountering resource conflicts

**Check status:**
```bash
aws cloudformation describe-stack-events \
  --stack-name fastish-prod \
  --max-items 10
```

**Common fix:**
```bash
# Delete and retry
npx cdk destroy
npx cdk deploy
```

## Cost Estimate

**Bootstrap Stack (fastish-prod):**
- IAM Roles: **Free**
- S3 Bucket (empty): **~$0.01/month**
- KMS Key: **$1.00/month**
- SSM Parameter: **Free**

**Total:** ~$1/month for bootstrap stack (before deploying applications)

**Note:** Actual application deployments (Druid, WebApp) have additional costs. See architecture-specific documentation for estimates.

## Cleanup

To remove the bootstrap stack:

```bash
# 1. Empty S3 bucket first (required)
BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name fastish-prod \
  --query 'Stacks[0].Outputs[?OutputKey==`AssetsBucketName`].OutputValue' \
  --output text)

aws s3 rm s3://${BUCKET_NAME} --recursive

# 2. Delete ECR images (optional)
REPO_NAME=$(aws cloudformation describe-stacks \
  --stack-name fastish-prod \
  --query 'Stacks[0].Outputs[?OutputKey==`ImagesRepositoryName`].OutputValue' \
  --output text)

aws ecr batch-delete-image \
  --repository-name ${REPO_NAME} \
  --image-ids imageTag=latest

# 3. Destroy stack
npx cdk destroy
```

**Warning:** Destroying the bootstrap stack will prevent future deployments of Fastish applications that depend on these resources.

## Learn More

- [Core Concepts →](concepts.md) - Understanding the yaml → model → construct pattern
- [Configuration Guide →](configuration.md) - Detailed configuration options
- [Requirements →](requirements.md) - Complete prerequisites list
- [Setup Guide →](setup.md) - Detailed setup instructions
