# Synthesizer

## Overview

A **Synthesizer** represents an AWS environment where infrastructure can be deployed. It stores the CDK bootstrap outputs, IAM roles, and storage locations required to orchestrate deployments through AWS CodePipeline.

Think of a Synthesizer as your "deployment target" - it defines **where** (AWS account/region) and **how** (IAM roles, S3 buckets) infrastructure will be deployed.

## What is a Synthesizer?

### Conceptual Definition

A Synthesizer is a collection of AWS resources that enable secure, automated infrastructure deployments:

- **Identity**: AWS Account ID and Region
- **Access**: IAM roles for cross-account deployment
- **Storage**: S3 buckets and ECR repositories for CDK assets
- **Security**: KMS keys for encryption, External ID for access control

### Configuration Structure

```typescript
interface Synthesizer {
  // Basic identification
  id: string;                    // Unique ID
  name: string;                  // Human-readable name (e.g., "production", "staging")

  // AWS environment
  account: string;               // AWS Account ID (12 digits)
  region: string;                // AWS Region (e.g., "us-west-2")

  // Security
  externalId: string;            // External ID for cross-account access
  subscriberRoleArn: string;     // IAM role ARN for deployment

  // CDK Bootstrap outputs
  cdk: {
    version: string;             // CDK bootstrap version (e.g., "21")

    kms: {
      key: string;               // KMS key ID for encryption
      alias: string;             // KMS key alias
    };

    ssm: {
      parameter: string;         // SSM parameter name for config storage
    };

    role: {
      handshake: string;         // ARN: Cross-account validation role
      exec: string;              // ARN: CloudFormation execution role
      deploy: string;            // ARN: Deployment role
      lookup: string;            // ARN: Resource lookup role
      filePublish: string;       // ARN: S3 asset publishing role
      imagePublish: string;      // ARN: ECR image publishing role
    };

    storage: {
      assetsBucket: string;      // S3 bucket name for CDK assets
      imagesRepo: string;        // ECR repository name for container images
    };
  };
}
```

## How Synthesizer Inputs Are Used

### 1. Account & Region → Environment Configuration

**Input:**
```json
{
  "account": "123456789012",
  "region": "us-west-2"
}
```

**Used in `cdk.context.json`:**
```json
{
  "hosted:account": "123456789012",
  "hosted:region": "us-west-2"
}
```

**Flows to CloudFormation:**
```java
// CDK App Environment
Environment env = Environment.builder()
    .account("123456789012")
    .region("us-west-2")
    .build();

// Used in every resource
UserPool userPool = UserPool.Builder.create(this, "UserPool")
    .env(env)  // Resources created in this account/region
    .build();
```

**Results in:**
- All resources created in AWS account `123456789012`
- All resources created in region `us-west-2`
- Availability zones: `us-west-2a`, `us-west-2b`, `us-west-2c`

### 2. External ID → Cross-Account Access

**Input:**
```json
{
  "externalId": "abc123-unique-key"
}
```

**Used in deployment pipeline:**
```typescript
// spaz-infra assumes subscriber's deployment role
const credentials = await sts.assumeRole({
  RoleArn: synthesizer.cdk.role.deploy,
  RoleSessionName: 'fastish-deployment',
  ExternalId: synthesizer.externalId,  // REQUIRED for security
  DurationSeconds: 3600,
}).promise();
```

**Trust policy in subscriber's account:**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "AWS": "arn:aws:iam::351619759866:root"
    },
    "Action": "sts:AssumeRole",
    "Condition": {
      "StringEquals": {
        "sts:ExternalId": "abc123-unique-key"
      }
    }
  }]
}
```

**Security benefits:**
- Prevents "confused deputy" problem
- Ensures only authorized systems can deploy
- Each subscriber has unique external ID
- External ID can be rotated without recreating roles

### 3. CDK Roles → Deployment Permissions

#### Handshake Role

**Purpose:** Validate synthesizer configuration (read-only)

**Input:**
```json
{
  "cdk.role.handshake": "arn:aws:iam::123456789012:role/fastish-handshake-role"
}
```

**Used during verification:**
```typescript
// Portal verifies synthesizer can be accessed
const credentials = await sts.assumeRole({
  RoleArn: synthesizer.cdk.role.handshake,
  ExternalId: synthesizer.externalId,
}).promise();

// Check resources exist
await s3.headBucket({ Bucket: synthesizer.cdk.storage.assetsBucket });
await ecr.describeRepositories({ repositoryNames: [synthesizer.cdk.storage.imagesRepo] });
await iam.getRole({ RoleName: 'fastish-deployment-role' });
```

**Permissions:**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "ecr:DescribeRepositories",
      "iam:GetRole",
      "iam:ListRoles",
      "kms:DescribeKey",
      "ssm:GetParameter"
    ],
    "Resource": "*"
  }]
}
```

#### Deployment Role

**Purpose:** Trigger and monitor CloudFormation deployments

**Input:**
```json
{
  "cdk.role.deploy": "arn:aws:iam::123456789012:role/fastish-deployment-role"
}
```

**Used in CodePipeline:**
```typescript
// spaz-infra WebappApi.java
var pipelineRole = Role.fromRoleName(
    this,
    "pipeline.role.lookup",
    "fastish-pipeline-role"
);

Pipeline.Builder.create(this, "WebappPipeline")
    .role(pipelineRole)  // Assumes deployment role
    .build();
```

**Permissions:**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "cloudformation:*",
      "codebuild:StartBuild",
      "codepipeline:StartPipelineExecution",
      "s3:GetObject",
      "s3:PutObject",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ],
    "Resource": "*"
  }]
}
```

#### Execution Role

**Purpose:** CloudFormation assumes this role to create resources

**Input:**
```json
{
  "cdk.role.exec": "arn:aws:iam::123456789012:role/fastish-cfn-exec-role"
}
```

**Used by CloudFormation:**
```yaml
# CloudFormation stack
Resources:
  DeploymentStack:
    Type: AWS::CloudFormation::Stack
    Properties:
      RoleARN: arn:aws:iam::123456789012:role/fastish-cfn-exec-role
      TemplateURL: https://s3.amazonaws.com/.../template.json
```

**Permissions (Service-Scoped for WebApp):**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "ec2:*",           // VPC, subnets, security groups
      "cognito-idp:*",   // User pools
      "apigateway:*",    // API Gateway
      "lambda:*",        // Lambda functions
      "dynamodb:*",      // DynamoDB tables
      "ses:*",           // Email service
      "route53:*",       // DNS records
      "acm:*",           // SSL certificates
      "iam:*",           // Service roles (scoped)
      "kms:*",           // Encryption keys
      "s3:*",            // S3 buckets
      "logs:*"           // CloudWatch Logs
    ],
    "Resource": "*"
  }]
}
```

### 4. Storage → CDK Assets

#### S3 Assets Bucket

**Input:**
```json
{
  "cdk.storage.assetsBucket": "fastish-assets-123456789012-us-west-2"
}
```

**Used in CDK synthesis:**
```typescript
// During 'cdk synth' and 'cdk deploy'
const assetBucket = synthesizer.cdk.storage.assetsBucket;

// Lambda function code uploaded
await s3.upload({
  Bucket: assetBucket,
  Key: 'assets/lambda-fn-abc123.zip',
  Body: lambdaCodeZip,
  ServerSideEncryption: 'aws:kms',
  SSEKMSKeyId: synthesizer.cdk.kms.key
}).promise();
```

**Asset manifest example:**
```json
{
  "version": "21.0.0",
  "files": {
    "lambda-fn-abc123.zip": {
      "source": {
        "path": "asset.lambda-fn-abc123.zip",
        "packaging": "zip"
      },
      "destinations": {
        "current_account-current_region": {
          "bucketName": "fastish-assets-123456789012-us-west-2",
          "objectKey": "assets/lambda-fn-abc123.zip"
        }
      }
    }
  }
}
```

#### ECR Images Repository

**Input:**
```json
{
  "cdk.storage.imagesRepo": "fastish-container-assets"
}
```

**Used for container-based Lambdas:**
```typescript
// Lambda container image deployment
const imageUri = `123456789012.dkr.ecr.us-west-2.amazonaws.com/${synthesizer.cdk.storage.imagesRepo}:lambda-api-v1`;

const lambdaFunction = new lambda.DockerImageFunction(this, 'ApiFunction', {
  code: lambda.DockerImageCode.fromImageAsset('./fn/api', {
    repository: synthesizer.cdk.storage.imagesRepo
  }),
});
```

### 5. KMS Key → Encryption

**Input:**
```json
{
  "cdk.kms.key": "abc123-def456-ghi789",
  "cdk.kms.alias": "alias/fastish-assets"
}
```

**Used in resource creation:**
```yaml
# S3 bucket encryption
AssetsBucket:
  Type: AWS::S3::Bucket
  Properties:
    BucketEncryption:
      ServerSideEncryptionConfiguration:
        - ServerSideEncryptionByDefault:
            SSEAlgorithm: aws:kms
            KMSMasterKeyID: !Sub "arn:aws:kms:${AWS::Region}:${AWS::AccountId}:key/abc123-def456-ghi789"

# DynamoDB table encryption
UserTable:
  Type: AWS::DynamoDB::Table
  Properties:
    SSESpecification:
      SSEEnabled: true
      SSEType: KMS
      KMSMasterKeyId: alias/fastish-assets
```

**Encrypted resources:**
- S3 buckets (CDK assets, logs)
- DynamoDB tables
- SSM parameters
- CloudWatch Logs
- SQS queues (if used)
- SNS topics (if used)

## Creating a Synthesizer

### Prerequisites

1. **AWS Account** with admin access
2. **AWS Region** selected
3. **CDK Bootstrap** completed:
   ```bash
   cdk bootstrap aws://123456789012/us-west-2
   ```

### Step 1: Collect Bootstrap Outputs

After `cdk bootstrap`, retrieve the outputs:

```bash
# Get CDK bootstrap stack outputs
aws cloudformation describe-stacks \
  --stack-name CDKToolkit \
  --query 'Stacks[0].Outputs' \
  --output json > cdk-bootstrap-outputs.json
```

**Example outputs:**
```json
[
  {
    "OutputKey": "BucketName",
    "OutputValue": "cdk-hnb659fds-assets-123456789012-us-west-2"
  },
  {
    "OutputKey": "ImageRepositoryName",
    "OutputValue": "cdk-hnb659fds-container-assets-123456789012-us-west-2"
  },
  {
    "OutputKey": "FilePublishingRoleArn",
    "OutputValue": "arn:aws:iam::123456789012:role/cdk-hnb659fds-file-publishing-role-123456789012-us-west-2"
  }
  // ... more outputs
]
```

### Step 2: Deploy Custom Bootstrap (Optional)

For enhanced security, deploy the Fastish custom bootstrap:

```bash
# Download template from portal or docs
curl -O https://docs.fasti.sh/templates/fastish-bootstrap.yaml

# Deploy with external ID
aws cloudformation create-stack \
  --stack-name fastish-bootstrap \
  --template-body file://fastish-bootstrap.yaml \
  --parameters \
    ParameterKey=ExternalId,ParameterValue=YOUR_UNIQUE_KEY \
  --capabilities CAPABILITY_NAMED_IAM
```

### Step 3: Configure Synthesizer

Create synthesizer configuration with collected values:

```json
{
  "name": "production",
  "account": "123456789012",
  "region": "us-west-2",
  "externalId": "YOUR_UNIQUE_KEY",
  "subscriberRoleArn": "arn:aws:iam::123456789012:role/fastish-deployment-role",
  "cdk": {
    "version": "21",
    "kms": {
      "key": "abc123-def456-ghi789",
      "alias": "alias/fastish-assets"
    },
    "ssm": {
      "parameter": "/cdk-bootstrap/hnb659fds/version"
    },
    "role": {
      "handshake": "arn:aws:iam::123456789012:role/fastish-handshake-role",
      "exec": "arn:aws:iam::123456789012:role/cdk-hnb659fds-cfn-exec-role-123456789012-us-west-2",
      "deploy": "arn:aws:iam::123456789012:role/cdk-hnb659fds-deploy-role-123456789012-us-west-2",
      "lookup": "arn:aws:iam::123456789012:role/cdk-hnb659fds-lookup-role-123456789012-us-west-2",
      "filePublish": "arn:aws:iam::123456789012:role/cdk-hnb659fds-file-publish-role-123456789012-us-west-2",
      "imagePublish": "arn:aws:iam::123456789012:role/cdk-hnb659fds-image-publish-role-123456789012-us-west-2"
    },
    "storage": {
      "assetsBucket": "cdk-hnb659fds-assets-123456789012-us-west-2",
      "imagesRepo": "cdk-hnb659fds-container-assets-123456789012-us-west-2"
    }
  }
}
```

## Common Scenarios

### Scenario 1: Single Environment

**Configuration:**
```json
{
  "name": "production",
  "account": "111111111111",
  "region": "us-east-1"
}
```

**Use case:** Small teams deploying everything to one AWS account

### Scenario 2: Multi-Environment (Same Account)

**Development:**
```json
{
  "name": "development",
  "account": "111111111111",
  "region": "us-west-2"
}
```

**Production:**
```json
{
  "name": "production",
  "account": "111111111111",
  "region": "us-east-1"
}
```

**Use case:** Separate by region for isolation, single account for billing

### Scenario 3: Multi-Environment (Separate Accounts)

**Development:**
```json
{
  "name": "development",
  "account": "111111111111",
  "region": "us-west-2"
}
```

**Production:**
```json
{
  "name": "production",
  "account": "222222222222",
  "region": "us-west-2"
}
```

**Use case:** Complete isolation, separate billing, strict access control

### Scenario 4: Multi-Region (DR/HA)

**Primary:**
```json
{
  "name": "production-us",
  "account": "111111111111",
  "region": "us-east-1"
}
```

**DR:**
```json
{
  "name": "production-eu",
  "account": "111111111111",
  "region": "eu-west-1"
}
```

**Use case:** Disaster recovery, high availability, global applications

## Troubleshooting

### Verification Fails

**Error:** `AccessDenied when assuming role`

**Checklist:**
1. Verify external ID matches exactly
2. Check role trust policy includes correct principal
3. Ensure role exists in specified account/region
4. Verify no SCPs blocking cross-account access

**Debug:**
```bash
# Test role assumption
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/fastish-handshake-role \
  --role-session-name test \
  --external-id YOUR_EXTERNAL_ID
```

### Assets Bucket Not Found

**Error:** `NoSuchBucket: The specified bucket does not exist`

**Solutions:**
1. Verify bucket name matches CDK bootstrap output
2. Check bucket is in correct region
3. Ensure CDK bootstrap completed successfully

```bash
# Verify bucket exists
aws s3 ls s3://cdk-hnb659fds-assets-123456789012-us-west-2 --region us-west-2
```

### KMS Key Access Denied

**Error:** `KMS.NotFoundException: Key 'alias/fastish-assets' not found`

**Solutions:**
1. Verify KMS key exists
2. Check key policy allows deployment role
3. Ensure key is in correct region

```bash
# Describe KMS key
aws kms describe-key --key-id alias/fastish-assets --region us-west-2
```

## Best Practices

1. **Unique Names**: Use descriptive names (`production-webapp`, not `prod1`)
2. **Separate Environments**: Different synthesizers for dev/staging/prod
3. **Rotate External IDs**: Periodically rotate external IDs for security
4. **Monitor Usage**: Track deployments and costs per synthesizer
5. **Document Configuration**: Keep synthesizer configs in version control
6. **Use Custom Bootstrap**: Enhanced security with service-scoped permissions
7. **Tag Resources**: Apply consistent tags for cost allocation

## Next Steps

- [Organization Configuration →](/workflow/organization.md)
- [Team Management →](/workflow/teams.md)
- [Creating Releases →](/workflow/release.md)
- [Custom Bootstrap Setup →](/getting-started/bootstrap/custom.md)
