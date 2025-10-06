# AWS CDK Bootstrap (Default Resources)

## Overview

Before deploying any fastish infrastructure, you must run the standard AWS CDK bootstrap command. This creates the default CDK toolkit resources that AWS CDK requires for all deployments.

## What Gets Created

The default CDK bootstrap creates essential resources in your AWS account:

### S3 Bucket
- **Name pattern**: `cdk-*-assets-<account-id>-<region>`
- **Purpose**: Stages deployment assets (CloudFormation templates, Lambda code, etc.)
- **Features**:
  - Versioning enabled
  - Encryption at rest
  - Lifecycle policies for cleanup

### ECR Repository
- **Name pattern**: `cdk-*-container-assets-<account-id>-<region>`
- **Purpose**: Stages Docker container images
- **Features**:
  - Image scanning
  - Lifecycle policies for image retention

### IAM Roles
- **CloudFormation execution role**: Deploys and manages stacks
- **File publishing role**: Uploads assets to S3
- **Image publishing role**: Pushes container images to ECR
- **Lookup role**: Discovers existing resources

### SSM Parameter
- **Path**: `/cdk-bootstrap/*/version`
- **Purpose**: Tracks bootstrap version for compatibility checks

## Prerequisites

- [AWS CLI configured](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html)
- AWS account with administrator access
- AWS CDK CLI installed: `npm install -g aws-cdk`

## Bootstrap Command

```bash
cdk bootstrap aws://<account-id>/<region>
```

### Example

```bash
# For account 123456789012 in us-west-2
cdk bootstrap aws://123456789012/us-west-2
```

## Multi-Region Setup

If you plan to deploy to multiple regions, bootstrap each region separately:

```bash
cdk bootstrap aws://123456789012/us-west-2
cdk bootstrap aws://123456789012/us-east-1
cdk bootstrap aws://123456789012/eu-west-1
```

## Multi-Account Setup

For cross-account deployments, bootstrap both accounts:

```bash
# Bootstrap target account (where resources will be deployed)
cdk bootstrap aws://111111111111/us-west-2

# Bootstrap deployment account (where CI/CD runs)
cdk bootstrap aws://222222222222/us-west-2 \
  --trust 111111111111 \
  --cloudformation-execution-policies 'arn:aws:iam::aws:policy/AdministratorAccess'
```

## Verification

After bootstrapping, verify the resources were created:

```bash
# Check S3 bucket
aws s3 ls | grep cdk-

# Check ECR repository
aws ecr describe-repositories --query 'repositories[?contains(repositoryName, `cdk`)].repositoryName'

# Check SSM parameter
aws ssm get-parameter --name /cdk-bootstrap/*/version
```

## Important Notes

- **One-time operation**: Bootstrap is required only once per account/region combination
- **Cost**: Bootstrap resources incur minimal costs (S3 storage, ECR if images are stored)
- **Security**: Bootstrap creates IAM roles with administrative permissions
- **Updates**: Re-run bootstrap to update to newer versions when upgrading CDK

## Troubleshooting

### "This stack uses assets, so the toolkit stack must be deployed" error

This means you haven't bootstrapped the account/region. Run the bootstrap command.

### Permission denied errors

Ensure your AWS credentials have administrator access or the following permissions:
- `cloudformation:*`
- `s3:*`
- `ecr:*`
- `iam:*`
- `ssm:*`

### Already bootstrapped

Re-running bootstrap on an already bootstrapped account/region will update the resources, not create duplicates.

## Next Steps

After CDK bootstrap is complete, proceed to:
- [Custom Bootstrap (Fastish Resources)](/getting-started/bootstrap/custom.md)

## Additional Resources

- [AWS CDK Bootstrapping Guide](https://docs.aws.amazon.com/cdk/v2/guide/bootstrapping.html)
- [CDK Bootstrap Command Reference](https://docs.aws.amazon.com/cdk/v2/guide/ref-cli-cmd-bootstrap.html)
