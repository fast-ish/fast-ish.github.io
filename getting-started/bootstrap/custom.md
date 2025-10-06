# Custom Bootstrap (Fastish Resources)

## Overview

The fastish bootstrap stack creates foundational AWS resources required for deploying fastish platform infrastructure and applications. This is deployed **after** the standard AWS CDK bootstrap.

## Prerequisites

- ✅ [AWS CDK Bootstrap](/getting-started/bootstrap/cdk.md) completed
- [Node.js 18+](https://nodejs.org/) installed
- [npm](https://www.npmjs.com/) installed
- AWS CLI configured with appropriate credentials

## What Gets Created

The bootstrap stack provisions three main resource categories:

### 1. IAM Roles (8 Specialized Roles)

| Role | Purpose |
|------|---------|
| **Handshake** | Establishes trust relationships with external AWS accounts |
| **Lookup** | Discovers and validates existing AWS resources during deployment |
| **Assets** | Manages S3 bucket operations for deployment assets |
| **Images** | Manages ECR repository operations for Docker images |
| **Deploy** | Executes CloudFormation stack deployments and updates |
| **Exec** | General CloudFormation execution for custom resources |
| **Druid Exec** | Specialized execution for Apache Druid deployments |
| **Webapp Exec** | Specialized execution for web application deployments |

### 2. Storage Resources

#### S3 Bucket
- Stores CDK deployment assets (templates, Lambda code, files)
- Versioning enabled
- Encryption at rest
- Lifecycle policies for cleanup

#### ECR Repository
- Stores Docker container images for Lambda and Fargate
- Image scanning enabled
- Lifecycle policies for image retention

### 3. Encryption & Parameters

#### KMS Key
- Encrypts sensitive data at rest (S3, secrets, parameters)
- Automatic key rotation
- Access controlled via IAM policies

#### KMS Alias
- Friendly name: `alias/fastish`
- Makes key reference easier

#### SSM Parameter
- Stores fastish version and configuration metadata
- Encrypted with KMS key
- Accessible to deployment roles

## Architecture

```
BootstrapStack (fastish-<synthesizer-name>)
├── FastishRoles (nested stack)
│   ├── handshake role
│   ├── lookup role
│   ├── assets role
│   ├── images role
│   ├── deploy role
│   ├── exec role
│   ├── druid exec role
│   └── webapp exec role
├── FastishStorage (nested stack)
│   ├── s3 assets bucket
│   └── ecr images repository
└── FastishKeys (nested stack)
    ├── kms encryption key + alias
    └── ssm version parameter
```

## Deployment Steps

### 1. Clone the Repository

```bash
gh repo clone fast-ish/bootstrap
cd bootstrap
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Build the Project

```bash
npm run build
```

### 4. Configure Deployment

Create or update `cdk.context.json`:

```json
{
  "synthesizer": {
    "name": "prod"
  }
}
```

The synthesizer name determines the stack name: `fastish-<name>` (e.g., `fastish-prod`)

### 5. Preview Changes

```bash
npx cdk synth
```

This generates the CloudFormation template without deploying.

### 6. Deploy Bootstrap Stack

```bash
npx cdk deploy
```

**What gets deployed**:
- 1 main CloudFormation stack: `fastish-<synthesizer-name>`
- 3 nested CloudFormation stacks: roles, storage, keys
- 8 IAM roles with specific permissions
- 1 S3 bucket for assets
- 1 ECR repository for container images
- 1 KMS key with alias for encryption
- 1 SSM parameter for version tracking

### 7. Capture Outputs

After deployment, the stack outputs a JSON object with all resource ARNs:

```json
{
  "roles": {
    "handshake": "arn:aws:iam::123456789012:role/...",
    "lookup": "arn:aws:iam::123456789012:role/...",
    "assets": "arn:aws:iam::123456789012:role/...",
    "images": "arn:aws:iam::123456789012:role/...",
    "deploy": "arn:aws:iam::123456789012:role/...",
    "exec": "arn:aws:iam::123456789012:role/...",
    "druidExec": "arn:aws:iam::123456789012:role/...",
    "webappExec": "arn:aws:iam::123456789012:role/..."
  },
  "storage": {
    "assets": "arn:aws:s3:::fastish-assets-...",
    "images": "arn:aws:ecr:us-west-2:123456789012:repository/fastish-images"
  },
  "keys": {
    "kms": {
      "key": "arn:aws:kms:us-west-2:123456789012:key/...",
      "alias": "alias/fastish"
    },
    "ssm": {
      "parameter": "arn:aws:ssm:us-west-2:123456789012:parameter/..."
    }
  }
}
```

**Important**: Save these values - fastish platform deployments will reference these resources.

## Useful Commands

| Command | Description |
|---------|-------------|
| `npm run build` | Compile TypeScript to JavaScript |
| `npm run watch` | Watch for file changes and auto-compile |
| `npm run test` | Run Jest unit tests |
| `npx cdk synth` | Generate CloudFormation template (preview) |
| `npx cdk diff` | Compare deployed stack with current code |
| `npx cdk deploy` | Deploy stack to AWS account/region |
| `npx cdk destroy` | Destroy stack (requires S3 bucket empty) |

## Cleanup

To remove the bootstrap stack:

### 1. Empty the S3 Bucket

```bash
# Get bucket name from stack outputs
BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name fastish-prod \
  --query 'Stacks[0].Outputs[?OutputKey==`AssetsBucketName`].OutputValue' \
  --output text)

# Empty bucket
aws s3 rm s3://${BUCKET_NAME} --recursive
```

### 2. Delete ECR Images (Optional)

```bash
# Get repository name
REPO_NAME=$(aws cloudformation describe-stacks \
  --stack-name fastish-prod \
  --query 'Stacks[0].Outputs[?OutputKey==`ImagesRepositoryName`].OutputValue' \
  --output text)

# Delete all images
aws ecr batch-delete-image \
  --repository-name ${REPO_NAME} \
  --image-ids imageTag=latest
```

### 3. Destroy the Stack

```bash
npx cdk destroy
```

> **Warning**: Destroying this stack will prevent deployments of any fastish applications that depend on these resources.

## Verification

Verify the bootstrap was successful:

```bash
# Check CloudFormation stack
aws cloudformation describe-stacks --stack-name fastish-prod

# List IAM roles
aws iam list-roles --query 'Roles[?contains(RoleName, `fastish`)].RoleName'

# Check S3 bucket
aws s3 ls | grep fastish

# Check ECR repository
aws ecr describe-repositories --query 'repositories[?contains(repositoryName, `fastish`)].repositoryName'

# Check KMS key
aws kms list-aliases --query 'Aliases[?AliasName==`alias/fastish`]'
```

## Troubleshooting

### Stack already exists

If you get a "stack already exists" error, either:
- Use a different synthesizer name in `cdk.context.json`
- Delete the existing stack first with `npx cdk destroy`

### Permission denied

Ensure your AWS credentials have permissions to create:
- CloudFormation stacks
- IAM roles and policies
- S3 buckets
- ECR repositories
- KMS keys
- SSM parameters

### Deployment fails on nested stacks

Nested stack failures are usually due to:
- IAM permission issues
- Resource naming conflicts
- Service quotas exceeded

Check CloudFormation console for detailed error messages.

## Next Steps

After bootstrap is complete:
- [Deploy Webapp Infrastructure](/webapp/overview.md)
- [Deploy Druid Infrastructure](/druid/overview.md)
- [Configure Service Quotas](/getting-started/service-quotas.md)

## Source Code

The bootstrap stack source code is available at:
- Repository: [fast-ish/bootstrap](https://github.com/fast-ish/bootstrap)
- Documentation: `/Users/bs/codes/fastish/v2/bootstrap/README.md`
