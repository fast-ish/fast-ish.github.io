# Setup

## Quick Start

Initialize your environment with the necessary AWS credentials and CDK configuration.

### 1. Clone the Bootstrap Repository

```bash
git clone git@github.com:fast-ish/bootstrap.git
cd bootstrap
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Configure CDK Context

Create a `cdk.context.json` file with your AWS account details:

```bash
cat <<EOF > cdk.context.json
{
  "host": {
    "account": "351619759866"
  },
  "synthesizer": {
    "name": "default",
    "account": "YOUR_AWS_ACCOUNT_ID",
    "region": "us-west-2",
    "externalId": "YOUR_API_KEY",
    "subscriberRoleArn": "YOUR_ROLE_ARN",
    "releases": ["all", "druid", "webapp"],
    "cdk": {
      "version": "21"
    }
  }
}
EOF
```

### 4. Deploy the Infrastructure

```bash
npx cdk deploy --require-approval never
```

## Configuration Options

### Synthesizer Configuration

| Field | Description | Required |
|-------|-------------|----------|
| `name` | Unique identifier for your synthesizer | Yes |
| `account` | Your AWS account ID | Yes |
| `region` | AWS region for deployment | Yes |
| `externalId` | API key for authentication | Yes |
| `subscriberRoleArn` | IAM role ARN for deployment | Yes |
| `releases` | Array of releases to deploy | Yes |

### Available Releases

- **all**: Deploy all available architectures
- **webapp**: Multi-tenant web application infrastructure
- **druid**: Real-time analytics platform with Apache Druid

## Environment Variables

You can also configure the deployment using environment variables:

```bash
export AWS_ACCOUNT_ID="123456789012"
export AWS_REGION="us-west-2"
export FASTISH_API_KEY="your-api-key"
export FASTISH_ROLE_ARN="arn:aws:iam::..."
```

## Verification

After deployment, verify the infrastructure:

```bash
# Check CloudFormation stacks
aws cloudformation list-stacks --query "StackSummaries[?contains(StackName, 'fastish')]"

# Verify SSM parameters
aws ssm get-parameters-by-path --path "/fastish" --recursive

# Check deployment outputs
cdk list
```

## Troubleshooting

### Common Issues

**Permission Denied**
- Ensure your AWS credentials have the necessary permissions
- Verify the IAM role ARN is correct

**Stack Already Exists**
- Use `cdk destroy` to remove existing stacks
- Or update the existing stack with `cdk deploy`

**Quota Exceeded**
- Check your AWS service quotas
- Request quota increases if needed

## Next Steps

- [Verify your deployment →](/getting-started/launch.md)
- [Configure optional resources →](/getting-started/optional-resources/grafana.md)
- [Explore the architecture catalog →](/webapp/overview.md)